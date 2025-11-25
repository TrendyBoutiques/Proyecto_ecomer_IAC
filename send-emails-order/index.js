const AWS = require('aws-sdk');
const ses = new AWS.SES();
const dynamoDb = new AWS.DynamoDB.DocumentClient();
const winston = require('winston');

const { USERS_TABLE, SENDER_EMAIL } = process.env;

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(winston.format.json()),
  transports: [new winston.transports.Console()],
});

/**
 * Nota importante sobre dependencias:
 * Esta función requiere la librería 'winston'.
 * Asegúrate de instalarla con `npm install winston` y empaquetarla en el .zip.
 */

exports.handler = async (event) => {
  logger.debug("Evento SQS recibido:", { event });

  const results = await Promise.allSettled(
    event.Records.map(async (record) => {
      try {
        logger.info(`Procesando messageId: ${record.messageId}`);
        const snsMessage = JSON.parse(record.body);
        const orderData = JSON.parse(snsMessage.Message);

        logger.debug("Datos de la orden recibidos:", { orderData });

        const { order } = orderData;
        if (!order || !order.orderId || !order.userId) {
          throw new Error("Datos de la orden incompletos en el mensaje de SNS");
        }

        logger.info(`Procesando orden ${order.orderId} para el usuario ${order.userId}`);

        const user = await getUserDetails(order.userId);
        if (!user.email) {
            throw new Error(`No se pudo encontrar el email para el usuario ${order.userId}`);
        }

        const subject = `Confirmación de tu pedido #${order.orderId}`;
        const emailBody = `Hola ${user.name || 'cliente'},

Gracias por tu compra. Hemos recibido tu pedido #${order.orderId} por un total de ${order.totalAmount} y lo estamos procesando.

Saludos,
El equipo de e-commerce.`;

        await sendEmail({
          to: user.email,
          subject: subject,
          body: emailBody,
        });

        return { status: "OK", orderId: order.orderId };

      } catch (error) {
        logger.error(`Error procesando messageId ${record.messageId}: ${error.message}`, { error });
        throw error; 
      }
    })
  );

  const batchItemFailures = results
    .map((result, index) => (result.status === "rejected" ? { itemIdentifier: event.Records[index].messageId } : null))
    .filter(Boolean);

  if (batchItemFailures.length > 0) {
    logger.warn('Algunos mensajes fallaron al procesar', { batchItemFailures });
  }

  return { batchItemFailures };
};

async function sendEmail({ to, subject, body }) {
    const params = {
        Destination: {
            ToAddresses: [to],
        },
        Message: {
            Body: {
                Text: { Data: body },
            },
            Subject: { Data: subject },
        },
        Source: SENDER_EMAIL,
    };

    logger.info(`Enviando email a ${to}...`);
    await ses.sendEmail(params).promise();
    logger.info(`Email enviado exitosamente a ${to}`);
}

async function getUserDetails(userId) {
    logger.debug(`Obteniendo detalles para el usuario ${userId}`);
    const params = {
        TableName: USERS_TABLE,
        Key: {
            userId: userId,
        },
    };
    const response = await dynamoDb.get(params).promise();
    if (!response.Item) {
        logger.warn(`Usuario con ID ${userId} no encontrado en DynamoDB.`);
        throw new Error(`Usuario con ID ${userId} no encontrado en DynamoDB.`);
    }
    logger.debug(`Detalles del usuario ${userId} obtenidos.`);
    return response.Item;
}
