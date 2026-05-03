import { Injectable, InternalServerErrorException, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../../prisma/prisma.service';
import PDFDocument from 'pdfkit';
import { createWriteStream, existsSync } from 'fs';
import { mkdir, access } from 'fs/promises';
import { join } from 'path';

@Injectable()
export class InvoiceService {
    private readonly invoiceDirectory: string;

    constructor(private readonly prisma: PrismaService, private readonly configService: ConfigService) {
        this.invoiceDirectory = this.configService.get<string>('INVOICE_STORAGE_PATH') || join(process.cwd(), 'storage', 'invoices');
    }

    async createInvoice(params: {
        userId: string;
        subscriptionId: string;
        amountCents: number;
        currency: string;
        invoiceNo?: string;
    }) {
        const invoiceNo = params.invoiceNo ?? this.buildInvoiceNumber();

        const invoice = await this.prisma.invoice.create({
            data: {
                invoiceNo,
                userId: params.userId,
                subscriptionId: params.subscriptionId,
                amountCents: params.amountCents,
                currency: params.currency.toUpperCase(),
                pdfUrl: '',
            },
        });

        const pdfFilePath = await this.generatePdf({
            invoiceId: invoice.id,
            invoiceNo: invoice.invoiceNo,
            subscriptionId: invoice.subscriptionId,
            userId: invoice.userId,
            amountCents: invoice.amountCents,
            currency: invoice.currency,
            createdAt: invoice.createdAt,
        });

        const pdfUrl = `/invoices/${invoice.id}/download`;

        await this.prisma.invoice.update({
            where: { id: invoice.id },
            data: { pdfUrl, },
        });

        return { ...invoice, pdfUrl, pdfFilePath };
    }

    async getInvoices(userId: string, isAdmin = false) {
        if (isAdmin) {
            return this.prisma.invoice.findMany({
                orderBy: { createdAt: 'desc' },
            });
        }

        return this.prisma.invoice.findMany({
            where: { userId },
            orderBy: { createdAt: 'desc' },
        });
    }

    async getInvoiceById(id: string, userId: string, isAdmin = false) {
        const invoice = await this.prisma.invoice.findUnique({
            where: { id },
        });

        if (!invoice) {
            throw new NotFoundException('Invoice not found');
        }

        if (!isAdmin && invoice.userId !== userId) {
            throw new NotFoundException('Invoice not found');
        }

        return invoice;
    }

    async getInvoicePdfPath(id: string) {
        const invoice = await this.prisma.invoice.findUnique({ where: { id } });
        if (!invoice) {
            throw new NotFoundException('Invoice not found');
        }

        const filePath = join(this.invoiceDirectory, `${id}.pdf`);
        try {
            await access(filePath);
            return filePath;
        } catch (error) {
            throw new NotFoundException('Invoice PDF not found');
        }
    }

    async exportInvoicesAsCsv(userId: string, isAdmin = false) {
        const invoices = await this.getInvoices(userId, isAdmin);
        const header = ['invoiceNo', 'userId', 'subscriptionId', 'amountCents', 'currency', 'pdfUrl', 'createdAt'];
        const rows = invoices.map((invoice) => [
            invoice.invoiceNo,
            invoice.userId,
            invoice.subscriptionId,
            invoice.amountCents.toString(),
            invoice.currency,
            invoice.pdfUrl,
            invoice.createdAt.toISOString(),
        ]);

        return [header, ...rows]
            .map((row) =>
                row
                    .map((value) => `"${String(value).replace(/"/g, '""')}"`)
                    .join(','),
            )
            .join('\n');
    }

    private buildInvoiceNumber() {
        const timestamp = Date.now();
        const randomSuffix = Math.floor(Math.random() * 900) + 100;
        return `INV-${timestamp}-${randomSuffix}`;
    }

    private async generatePdf(params: {
        invoiceId: string;
        invoiceNo: string;
        subscriptionId: string;
        userId: string;
        amountCents: number;
        currency: string;
        createdAt: Date;
    }) {
        try {
            await mkdir(this.invoiceDirectory, { recursive: true });
            const filePath = join(this.invoiceDirectory, `${params.invoiceId}.pdf`);
            const doc = new PDFDocument({ size: 'A4', margin: 50 });
            const stream = createWriteStream(filePath);

            doc.pipe(stream);

            doc.fontSize(22).text('Invoice', { align: 'center' });
            doc.moveDown();
            doc.fontSize(12).text(`Invoice No: ${params.invoiceNo}`);
            doc.text(`Date: ${params.createdAt.toISOString().split('T')[0]}`);
            doc.text(`User ID: ${params.userId}`);
            doc.moveDown();

            doc.fontSize(14).text('Payment Details');
            doc.moveDown(0.5);
            doc.fontSize(12).text(`Amount: ${(params.amountCents / 100).toFixed(2)} ${params.currency}`);
            doc.text(`Subscription ID: ${params.subscriptionId}`);
            doc.moveDown();

            doc.text('Thank you for your purchase.', { align: 'left' });
            doc.end();

            await new Promise<void>((resolve, reject) => {
                stream.on('finish', () => resolve());
                stream.on('error', (error) => reject(error));
            });

            if (!existsSync(filePath)) {
                throw new InternalServerErrorException('Failed to create invoice PDF');
            }

            return filePath;
        } catch (error) {
            throw new InternalServerErrorException(`Invoice PDF generation failed: ${error}`);
        }
    }
}
