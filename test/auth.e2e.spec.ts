/**
 * Auth E2E Tests
 *
 * These tests run against a real PostgreSQL + Redis instance.
 * They cover the full flow: register → login → refresh → me → forgot/reset password.
 *
 * Run with:  npm run test -- test/auth.e2e.spec.ts
 * Requires DATABASE_URL and all JWT env vars to be set (see .env.example).
 */
import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import * as request from 'supertest';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';

describe('Auth — E2E', () => {
  let app: INestApplication;
  let prisma: PrismaService;

  const testEmail = `e2e-auth-${Date.now()}@test.local`;
  const testPassword = 'Test@Pass123';

  let accessToken: string;
  let refreshToken: string;

  beforeAll(async () => {
    const module: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = module.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
    app.setGlobalPrefix('api');
    await app.init();

    prisma = module.get(PrismaService);
  });

  afterAll(async () => {
    // Clean up test user
    await prisma.user.deleteMany({ where: { email: testEmail } });
    await app.close();
  });

  // ── Register ────────────────────────────────────────────────────────────────

  it('POST /api/auth/register — creates user and returns tokens', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/auth/register')
      .send({ email: testEmail, password: testPassword })
      .expect(201);

    expect(res.body).toHaveProperty('accessToken');
    expect(res.body).toHaveProperty('refreshToken');
    expect(typeof res.body.accessToken).toBe('string');

    accessToken = res.body.accessToken;
    refreshToken = res.body.refreshToken;
  });

  it('POST /api/auth/register — rejects duplicate email', async () => {
    await request(app.getHttpServer())
      .post('/api/auth/register')
      .send({ email: testEmail, password: testPassword })
      .expect(400);
  });

  it('POST /api/auth/register — rejects weak password', async () => {
    await request(app.getHttpServer())
      .post('/api/auth/register')
      .send({ email: 'other@test.local', password: 'short' })
      .expect(400);
  });

  // ── Login ───────────────────────────────────────────────────────────────────

  it('POST /api/auth/login — valid credentials return tokens', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/auth/login')
      .send({ email: testEmail, password: testPassword })
      .expect(201);

    expect(res.body).toHaveProperty('accessToken');
    accessToken = res.body.accessToken;
    refreshToken = res.body.refreshToken;
  });

  it('POST /api/auth/login — wrong password returns 401', async () => {
    await request(app.getHttpServer())
      .post('/api/auth/login')
      .send({ email: testEmail, password: 'WrongPassword1' })
      .expect(401);
  });

  it('POST /api/auth/login — unknown email returns 401', async () => {
    await request(app.getHttpServer())
      .post('/api/auth/login')
      .send({ email: 'nobody@nowhere.com', password: testPassword })
      .expect(401);
  });

  // ── Me (authenticated) ──────────────────────────────────────────────────────

  it('GET /api/auth/me — returns user profile with valid token', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/auth/me')
      .set('Authorization', `Bearer ${accessToken}`)
      .expect(200);

    expect(res.body.email).toBe(testEmail);
    expect(res.body).not.toHaveProperty('password');
  });

  it('GET /api/auth/me — rejects request without token', async () => {
    await request(app.getHttpServer())
      .get('/api/auth/me')
      .expect(401);
  });

  it('GET /api/auth/me — rejects invalid token', async () => {
    await request(app.getHttpServer())
      .get('/api/auth/me')
      .set('Authorization', 'Bearer invalid.token.here')
      .expect(401);
  });

  // ── Token refresh ───────────────────────────────────────────────────────────

  it('POST /api/auth/refresh — returns new tokens', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/auth/refresh')
      .send({ refreshToken })
      .expect(201);

    expect(res.body).toHaveProperty('accessToken');
    accessToken = res.body.accessToken;
  });

  it('POST /api/auth/refresh — rejects invalid refresh token', async () => {
    await request(app.getHttpServer())
      .post('/api/auth/refresh')
      .send({ refreshToken: 'bad.refresh.token' })
      .expect(403);
  });

  // ── Forgot / Reset password ─────────────────────────────────────────────────

  it('POST /api/auth/forgot-password — always returns 200 (no enum)', async () => {
    // Known email
    await request(app.getHttpServer())
      .post('/api/auth/forgot-password')
      .send({ email: testEmail })
      .expect(200);

    // Unknown email — same response (no enumeration)
    await request(app.getHttpServer())
      .post('/api/auth/forgot-password')
      .send({ email: 'doesnotexist@test.local' })
      .expect(200);
  });

  it('POST /api/auth/reset-password — rejects invalid token', async () => {
    await request(app.getHttpServer())
      .post('/api/auth/reset-password')
      .send({
        token: '00000000-0000-0000-0000-000000000000',
        password: 'NewPassword123',
      })
      .expect(400);
  });

  it('POST /api/auth/reset-password — resets password with valid token', async () => {
    // Create a token directly in DB for this test
    const token = '11111111-1111-1111-1111-111111111111';
    await prisma.passwordResetToken.deleteMany({ where: { email: testEmail } });
    await prisma.passwordResetToken.create({
      data: {
        email: testEmail,
        token,
        expiresAt: new Date(Date.now() + 3_600_000),
      },
    });

    await request(app.getHttpServer())
      .post('/api/auth/reset-password')
      .send({ token, password: 'NewSecurePass123' })
      .expect(200);

    // Token should be consumed — second use fails
    await request(app.getHttpServer())
      .post('/api/auth/reset-password')
      .send({ token, password: 'AnotherPass123' })
      .expect(400);

    // Old password no longer works
    await request(app.getHttpServer())
      .post('/api/auth/login')
      .send({ email: testEmail, password: testPassword })
      .expect(401);

    // New password works
    await request(app.getHttpServer())
      .post('/api/auth/login')
      .send({ email: testEmail, password: 'NewSecurePass123' })
      .expect(201);
  });
});
