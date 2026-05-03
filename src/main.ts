import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { json } from 'body-parser';
import { AppModule } from './app.module';
import { ConfigService } from '@nestjs/config';

async function bootstrap() {
    const app = await NestFactory.create(AppModule);
    const configService = app.get(ConfigService);

    app.use(
        json({
            verify: (req, _res, buf) => {
                (req as any).rawBody = buf;
            },
        }),
    );
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
    app.setGlobalPrefix('api');

    const port = configService.get<number>('PORT') || 3000;
    await app.listen(port);
    console.log(`Application is running on: http://localhost:${port}/api`);
}

bootstrap();
