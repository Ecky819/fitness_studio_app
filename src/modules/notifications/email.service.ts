import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as nodemailer from 'nodemailer';

@Injectable()
export class EmailService {
    private transporter: nodemailer.Transporter;

    constructor(private readonly configService: ConfigService) {
        this.transporter = nodemailer.createTransport({
            host: this.configService.get<string>('SMTP_HOST') || 'smtp.gmail.com',
            port: this.configService.get<number>('SMTP_PORT') || 587,
            secure: false,
            auth: {
                user: this.configService.get<string>('SMTP_USER'),
                pass: this.configService.get<string>('SMTP_PASS'),
            },
        });
    }

    async sendEmail(to: string, subject: string, html: string): Promise<void> {
        try {
            await this.transporter.sendMail({
                from: this.configService.get<string>('SMTP_FROM') || 'noreply@fitnessstudio.com',
                to,
                subject,
                html,
            });
        } catch (error) {
            console.error('Email sending failed:', error);
            throw error;
        }
    }

    async sendPaymentFailedNotification(email: string, userName: string, amount: string): Promise<void> {
        const subject = '🚨 Payment Failed - NextGen Gym Access Restricted';
        const html = this.getStyledEmailTemplate(`
            <h1 style="color: #e74c3c;">Payment Failed</h1>
            <p>Hi ${userName},</p>
            <p>We were unable to process your payment of <strong>${amount}</strong> for your NextGen Gym membership.</p>
            <div style="background: #fff3cd; border: 1px solid #ffeaa7; padding: 15px; border-radius: 5px; margin: 20px 0;">
                <strong>⚠️ Important:</strong> Your gym access may be restricted until payment is resolved.
            </div>
            <p>Please update your payment method immediately to restore full access to all gym facilities.</p>
            <div style="text-align: center; margin: 30px 0;">
                <a href="${this.configService.get<string>('FRONTEND_URL')}/billing" style="background: #3498db; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; font-weight: bold;">Update Payment Method</a>
            </div>
            <p>Need help? Contact our support team at support@nextgengym.com or call (555) 123-GYM.</p>
        `);
        await this.sendEmail(email, subject, html);
    }

    async sendAccessRevokedNotification(email: string, userName: string, reason: string): Promise<void> {
        const subject = '🚫 NextGen Gym Access Revoked';
        const html = this.getStyledEmailTemplate(`
            <h1 style="color: #e74c3c;">Access Revoked</h1>
            <p>Hi ${userName},</p>
            <p>Your access to NextGen Gym facilities has been temporarily revoked.</p>
            <div style="background: #f8d7da; border: 1px solid #f5c6cb; padding: 15px; border-radius: 5px; margin: 20px 0;">
                <strong>Reason:</strong> ${reason}
            </div>
            <p>To restore your access, please contact our support team or update your account information.</p>
            <div style="text-align: center; margin: 30px 0;">
                <a href="${this.configService.get<string>('FRONTEND_URL')}/support" style="background: #e74c3c; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; font-weight: bold;">Contact Support</a>
            </div>
            <p>We apologize for any inconvenience and are here to help resolve this quickly.</p>
        `);
        await this.sendEmail(email, subject, html);
    }

    async sendMembershipExpiringNotification(email: string, userName: string, daysLeft: number): Promise<void> {
        const subject = `⏰ NextGen Gym Membership Expires in ${daysLeft} Days`;
        const urgencyColor = daysLeft <= 3 ? '#e74c3c' : '#f39c12';
        const html = this.getStyledEmailTemplate(`
            <h1 style="color: ${urgencyColor};">Membership Expiring Soon</h1>
            <p>Hi ${userName},</p>
            <p>Your NextGen Gym membership will expire in <strong>${daysLeft} days</strong>.</p>
            <div style="background: #d4edda; border: 1px solid #c3e6cb; padding: 15px; border-radius: 5px; margin: 20px 0;">
                <strong>💪 Don't lose access to:</strong>
                <ul style="margin: 10px 0; padding-left: 20px;">
                    <li>24/7 gym access</li>
                    <li>Premium equipment</li>
                    <li>Group fitness classes</li>
                    <li>Personal training sessions</li>
                </ul>
            </div>
            <p>Renew now to maintain uninterrupted access to your fitness journey.</p>
            <div style="text-align: center; margin: 30px 0;">
                <a href="${this.configService.get<string>('FRONTEND_URL')}/billing" style="background: #27ae60; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; font-weight: bold;">Renew Membership</a>
            </div>
            <p>Questions? We're here to help at support@nextgengym.com</p>
        `);
        await this.sendEmail(email, subject, html);
    }

    async sendPasswordResetEmail(email: string, resetLink: string): Promise<void> {
        const subject = '🔐 Reset Your NextGen Gym Password';
        const html = this.getStyledEmailTemplate(`
            <h1 style="color: #3498db;">Password Reset Request</h1>
            <p>We received a request to reset your password. Click the button below to set a new one.</p>
            <p style="color: #666; font-size: 14px;">This link expires in <strong>1 hour</strong> and can only be used once.</p>
            <div style="text-align: center; margin: 30px 0;">
                <a href="${resetLink}"
                   style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                          color: white; padding: 14px 32px; text-decoration: none;
                          border-radius: 6px; font-weight: bold; font-size: 16px;
                          display: inline-block;">
                    Reset Password
                </a>
            </div>
            <p style="color: #999; font-size: 13px;">
                If you didn't request a password reset, you can safely ignore this email.
                Your password won't be changed.
            </p>
            <p style="color: #999; font-size: 13px;">
                Or copy and paste this link: <br>
                <a href="${resetLink}" style="color: #3498db; word-break: break-all;">${resetLink}</a>
            </p>
        `);
        await this.sendEmail(email, subject, html);
    }

    private getStyledEmailTemplate(content: string): string {
        return `
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>NextGen Gym</title>
            </head>
            <body style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; background: #f8f9fa;">
                <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 20px; text-align: center;">
                    <h1 style="color: white; margin: 0; font-size: 28px;">🏋️ NextGen Gym</h1>
                    <p style="color: #e8eaf6; margin: 5px 0 0 0; font-size: 14px;">Where Fitness Meets Technology</p>
                </div>
                <div style="background: white; margin: 20px; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
                    ${content}
                </div>
                <div style="background: #343a40; color: white; padding: 20px; text-align: center; margin: 20px; border-radius: 10px;">
                    <p style="margin: 0; font-size: 14px;">
                        <strong>NextGen Gym</strong><br>
                        123 Fitness Street, Gym City, GC 12345<br>
                        📞 (555) 123-GYM | 📧 support@nextgengym.com<br>
                        🕒 24/7 Access | 💳 Secure Payments
                    </p>
                    <div style="margin-top: 15px; padding-top: 15px; border-top: 1px solid #495057;">
                        <a href="${this.configService.get<string>('FRONTEND_URL')}/privacy" style="color: #adb5bd; text-decoration: none; margin: 0 10px;">Privacy Policy</a> |
                        <a href="${this.configService.get<string>('FRONTEND_URL')}/terms" style="color: #adb5bd; text-decoration: none; margin: 0 10px;">Terms of Service</a> |
                        <a href="${this.configService.get<string>('FRONTEND_URL')}/unsubscribe" style="color: #adb5bd; text-decoration: none; margin: 0 10px;">Unsubscribe</a>
                    </div>
                </div>
            </body>
            </html>
        `;
    }
}
