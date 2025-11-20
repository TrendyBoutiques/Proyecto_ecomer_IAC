const AWS = require('aws-sdk');
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
const sns = new AWS.SNS();
const dynamoDb = new AWS.DynamoDB.DocumentClient();
const winston = require('winston');

const { STRIPE_WEBHOOK_SECRET, SNS_TOPIC_ARN, ORDERS_TABLE } = process.env;

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(winston.format.json()),
  transports: [new winston.transports.Console()],
});

/**
 * Nota importante sobre dependencias:
 * Esta función requiere las librerías 'stripe' y 'winston'.
 * Asegúrate de instalarlas con `npm install stripe winston` y empaquetarlas en el .zip.
 */

exports.handler = async (event) => {
  logger.info("Webhook de Stripe recibido");

  let stripeEvent;
  const signature = event.headers['Stripe-Signature'];

  try {
    stripeEvent = stripe.webhooks.constructEvent(event.body, signature, STRIPE_WEBHOOK_SECRET);
    logger.debug('Firma del webhook de Stripe verificada exitosamente', { eventType: stripeEvent.type });
  } catch (err) {
    logger.error(`Error al verificar la firma del webhook: ${err.message}`);
    return {
      statusCode: 400,
      body: `Webhook Error: ${err.message}`,
    };
  }

  // Manejar el evento
  if (stripeEvent.type === 'payment_intent.succeeded') {
    const paymentIntent = stripeEvent.data.object;
    logger.info(`PaymentIntent ${paymentIntent.id} fue exitoso!`);

    const orderId = paymentIntent.metadata.orderId;
    if (!orderId) {
        logger.error('Error: No se encontró orderId en los metadatos del PaymentIntent', { paymentIntentId: paymentIntent.id });
        return { statusCode: 200, body: 'Error: Missing orderId in metadata' };
    }

    try {
      // 1. Actualizar la orden en DynamoDB a 'PAID'
      logger.info(`Actualizando orden ${orderId} a PAID.`);
      const updateParams = {
        TableName: ORDERS_TABLE,
        Key: { orderId: orderId },
        UpdateExpression: 'set #status = :status',
        ExpressionAttributeNames: { '#status': 'status' },
        ExpressionAttributeValues: { ':status': 'PAID' },
        ReturnValues: "ALL_NEW"
      };
      
      const updatedOrder = await dynamoDb.update(updateParams).promise();
      logger.info(`Orden ${orderId} actualizada exitosamente.`);

      // 2. Publicar mensaje en SNS para notificar por email
      logger.info(`Publicando mensaje para la orden ${orderId} en SNS.`);
      const snsParams = {
        TopicArn: SNS_TOPIC_ARN,
        Message: JSON.stringify({
          type: 'ORDER_PAID',
          order: updatedOrder.Attributes
        }),
        MessageAttributes: {
            'eventType': {
                DataType: 'String',
                StringValue: 'ORDER_PAID'
            }
        }
      };

      await sns.publish(snsParams).promise();
      logger.info(`Mensaje para la orden ${orderId} publicado exitosamente.`);

    } catch (dbError) {
      logger.error(`Error al procesar la orden ${orderId}: ${dbError.message}`, { error: dbError });
      return { statusCode: 500, body: `Internal Server Error: ${dbError.message}` };
    }
  } else {
    logger.info(`Evento de Stripe no manejado: ${stripeEvent.type}`);
  }

  // Devolver una respuesta 200 para acusar recibo del evento a Stripe
  return { statusCode: 200, body: JSON.stringify({ received: true }) };
};