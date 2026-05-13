import {
  OnGatewayConnection,
  OnGatewayDisconnect,
  OnGatewayInit,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { Server, WebSocket } from 'ws';
import { Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';

interface TenantClient {
  ws: WebSocket;
  tenantId: string;
}

/**
 * WebSocket gateway that streams real-time occupancy data to connected clients.
 *
 * Protocol:
 *   Connect  → ws://host/ws/occupancy
 *   Client sends (after connect):
 *     { "type": "subscribe", "token": "<JWT>" }
 *   Server replies:
 *     { "type": "subscribed", "tenantId": "...", "count": N }
 *   Ongoing pushes:
 *     { "type": "occupancy_update", "tenantId": "...", "count": N, "timestamp": "..." }
 *
 * Unauthenticated clients receive no data and are disconnected after 10 s.
 */
@WebSocketGateway({ path: '/ws/occupancy' })
export class OccupancyGateway
  implements OnGatewayInit, OnGatewayConnection, OnGatewayDisconnect
{
  @WebSocketServer()
  server!: Server;

  private readonly logger = new Logger(OccupancyGateway.name);
  private readonly clients = new Map<WebSocket, TenantClient>();
  private readonly authTimeouts = new Map<WebSocket, ReturnType<typeof setTimeout>>();

  constructor(
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
  ) {}

  afterInit(_server: Server) {
    this.logger.log('Occupancy WebSocket gateway initialised');
  }

  handleConnection(ws: WebSocket) {
    // Give the client 10 s to authenticate, otherwise close
    const timeout = setTimeout(() => {
      if (!this.clients.has(ws)) {
        ws.close(4001, 'Authentication timeout');
      }
    }, 10_000);

    this.authTimeouts.set(ws, timeout);

    ws.on('message', (raw) => void this.handleMessage(ws, raw.toString()));
  }

  handleDisconnect(ws: WebSocket) {
    clearTimeout(this.authTimeouts.get(ws));
    this.authTimeouts.delete(ws);
    this.clients.delete(ws);
  }

  broadcast(tenantId: string, count: number) {
    const payload = JSON.stringify({
      type: 'occupancy_update',
      tenantId,
      count,
      timestamp: new Date().toISOString(),
    });

    this.clients.forEach((client) => {
      if (client.tenantId === tenantId && client.ws.readyState === WebSocket.OPEN) {
        client.ws.send(payload);
      }
    });
  }

  private async handleMessage(ws: WebSocket, raw: string) {
    try {
      const msg = JSON.parse(raw) as { type: string; token?: string };

      if (msg.type !== 'subscribe' || !msg.token) return;

      const payload = await this.jwtService.verifyAsync(msg.token, {
        secret: this.configService.getOrThrow<string>('JWT_ACCESS_SECRET'),
      });

      const tenantId: string = payload.tenantId;
      if (!tenantId) {
        ws.close(4002, 'Missing tenant context');
        return;
      }

      clearTimeout(this.authTimeouts.get(ws));
      this.authTimeouts.delete(ws);
      this.clients.set(ws, { ws, tenantId });

      ws.send(JSON.stringify({ type: 'subscribed', tenantId }));
    } catch {
      ws.close(4003, 'Authentication failed');
    }
  }
}
