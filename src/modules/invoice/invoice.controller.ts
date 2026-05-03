import { Controller, Get, Param, Query, Res, UseGuards } from '@nestjs/common';
import { Response } from 'express';
import { InvoiceService } from './invoice.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@Controller('invoices')
@UseGuards(JwtAuthGuard)
export class InvoiceController {
    constructor(private readonly invoiceService: InvoiceService) { }

    @Get('export')
    async exportCsv(@CurrentUser() user: any, @Res() res: Response) {
        const isAdmin = user?.role === 'ADMIN';
        const csv = await this.invoiceService.exportInvoicesAsCsv(user?.sub, isAdmin);
        res.setHeader('Content-Type', 'text/csv');
        res.setHeader('Content-Disposition', 'attachment; filename="invoices.csv"');
        res.send(csv);
    }

    @Get()
    async getInvoices(@CurrentUser() user: any) {
        const isAdmin = user?.role === 'ADMIN';
        return this.invoiceService.getInvoices(user?.sub, isAdmin);
    }

    @Get(':id')
    async getInvoice(@Param('id') id: string, @CurrentUser() user: any) {
        const isAdmin = user?.role === 'ADMIN';
        return this.invoiceService.getInvoiceById(id, user?.sub, isAdmin);
    }

    @Get(':id/download')
    async downloadInvoice(@Param('id') id: string, @CurrentUser() user: any, @Res() res: Response) {
        const isAdmin = user?.role === 'ADMIN';
        await this.invoiceService.getInvoiceById(id, user?.sub, isAdmin);
        const pdfPath = await this.invoiceService.getInvoicePdfPath(id);
        res.setHeader('Content-Type', 'application/pdf');
        res.setHeader('Content-Disposition', `attachment; filename="invoice-${id}.pdf"`);
        res.sendFile(pdfPath);
    }
}
