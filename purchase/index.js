const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
const winston = require('winston');

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(winston.format.json()),
  transports: [new winston.transports.Console()],
});

/**
 * Nota importante sobre dependencias:
 * Esta función requiere la librería 'stripe' y 'winston'.
 * Asegúrate de instalarlas en el directorio de la función con `npm install stripe winston`
 * y de empaquetarlas en el .zip que se sube a Lambda.
 */

exports.handler = async (event) => {
  logger.info("Evento recibido para crear intención de pago");

  try {
    const { amount, currency, orderId } = JSON.parse(event.body);

    if (!amount || !currency || !orderId) {
      logger.warn('Faltan parámetros en la solicitud', { amount, currency, orderId });
      return {
        statusCode: 400,
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ message: "Amount, currency, and orderId are required." })
      };
    }

    // Crea una Intención de Pago en Stripe
    logger.info(`Creando intención de pago para la orden ${orderId}`);
    const paymentIntent = await stripe.paymentIntents.create({
      amount: amount, // El monto debe estar en la unidad más pequeña (ej. centavos)
      currency: currency,
      automatic_payment_methods: {
        enabled: true,
      },
      metadata: {
        orderId: orderId // Guardar el ID de la orden en los metadatos
      }
    });

    logger.info(`Intención de pago ${paymentIntent.id} creada exitosamente para la orden ${orderId}`);

    // Devuelve el client_secret al frontend
    return {
      statusCode: 200,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ clientSecret: paymentIntent.client_secret })
    };

  } catch (error) {
    logger.error("Error al crear la intención de pago:", { error: error.message });
    return {
      statusCode: 500,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ message: error.message })
    };
  }
};