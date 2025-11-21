
  const AWS = require('aws-sdk');
  const dynamoDb = new AWS.DynamoDB.DocumentClient();
  const winston = require('winston');

  // Configuración de Winston (Logging)
  const logger = winston.createLogger({
    level: process.env.LOG_LEVEL || 'info',
    format: winston.format.combine(
      winston.format.timestamp(),
      winston.format.json()
    ),
    transports: [
      new winston.transports.Console()
    ],
  });

  // Nombre de las tablas de DynamoDB
  const ORDERS_TABLE = process.env.ORDERS_TABLE;
  const SHIPPING_TABLE = process.env.SHIPPING_TABLE;

  exports.handler = async (event) => {
    logger.info("Evento recibido", { event });

    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event;
    const action = body.action;

    switch (action) {
      case 'getOrder':
        return await getOrder(body);
      case 'listOrders':
        return await listOrders(body);
      case 'getShippingStatus':
        return await getShippingStatus(body);
      default:
        logger.warn("Acción no válida", { action });
        return {
          statusCode: 400,
          body: JSON.stringify({ message: 'Acción no válida' }),
        };
    }
  };

  // Obtener una orden por su ID
  async function getOrder(event) {
    const { orderId } = event;

    if (!orderId) {
      logger.error("Falta el parámetro orderId", { event });
      return {
        statusCode: 400,
        body: JSON.stringify({ message: 'Falta el parámetro orderId' }),
      };
    }

    const params = {
      TableName: ORDERS_TABLE,
      Key: { orderId }
    };

    try {
      const result = await dynamoDb.get(params).promise();
      if (!result.Item) {
        logger.warn("Orden no encontrada", { orderId });
        return {
          statusCode: 404,
          body: JSON.stringify({ message: 'Orden no encontrada' }),
        };
      }

      logger.info("Orden obtenida exitosamente", { orderId });
      return {
        statusCode: 200,
        body: JSON.stringify(result.Item),
      };
    } catch (error) {
      logger.error("Error al obtener la orden", { error });
      return {
        statusCode: 500,
        body: JSON.stringify({ message: 'Error al obtener la orden' }),
      };
    }
  }

  // Listar todas las órdenes de un usuario
  async function listOrders(event) {
      const { userId } = event;
      if (!userId) {
          logger.error("Falta el parámetro userId", { event });
          return {
              statusCode: 400,
              body: JSON.stringify({ message: 'Falta el parámetro userId' }),
          };
      }

    const params = {
      TableName: ORDERS_TABLE,
      IndexName: 'UserOrdersIndex', // Asume que existe un GSI para buscar por userId
      KeyConditionExpression: 'userId = :userId',
      ExpressionAttributeValues: {
          ':userId': userId
      }
    };

    try {
      const result = await dynamoDb.query(params).promise();
      logger.info("Órdenes listadas exitosamente para el usuario", { userId });
      return {
        statusCode: 200,
        body: JSON.stringify(result.Items),
      };
    } catch (error) {
      logger.error("Error al listar las órdenes", { error });
      return {
        statusCode: 500,
        body: JSON.stringify({ message: 'Error al listar las órdenes' }),
      };
    }
  }

  // Obtener el estado de un envío por orderId
  async function getShippingStatus(event) {
      const { orderId } = event;
      if (!orderId) {
          logger.error("Falta el parámetro orderId", { event });
          return {
              statusCode: 400,
              body: JSON.stringify({ message: 'Falta el parámetro orderId' }),
          };
      }

      const params = {
          TableName: SHIPPING_TABLE,
          IndexName: 'OrderShippingIndex', // Asume que existe un GSI para buscar por orderId
          KeyConditionExpression: 'orderId = :orderId',
          ExpressionAttributeValues: {
              ':orderId': orderId
          }
      };

      try {
          const result = await dynamoDb.query(params).promise();
          if (!result.Items || result.Items.length === 0) {
              logger.warn("Envío no encontrado para la orden", { orderId });
              return {
                  statusCode: 404,
                  body: JSON.stringify({ message: 'Envío no encontrado para esta orden' })
              };
          }
          logger.info("Estado de envío obtenido exitosamente", { orderId });
          return {
              statusCode: 200,
              body: JSON.stringify(result.Items[0]) // Devuelve el primer resultado del envío
          };
      } catch (error) {
          logger.error("Error al obtener el estado del envío", { error });
          return {
              statusCode: 500,
              body: JSON.stringify({ message: 'Error al obtener el estado del envío' })
          };
      }
  }

