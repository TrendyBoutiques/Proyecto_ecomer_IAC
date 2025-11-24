const AWS = require('aws-sdk');
const cognito = new AWS.CognitoIdentityServiceProvider();
const winston = require('winston');

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(winston.format.json()),
  transports: [new winston.transports.Console()],
});

exports.handler = async (event) => {
  logger.debug('Evento de registro recibido', { event });
  const { action, email, password, confirmationCode } = JSON.parse(event.body);
  const { COGNITO_USER_POOL_ID, COGNITO_CLIENT_ID } = process.env;

  switch (action) {
    case 'register':
      try {
        logger.info(`Iniciando registro para ${email}`);
        const { userSub } = await cognito.signUp({
          ClientId: COGNITO_CLIENT_ID,
          Username: email,
          Password: password,
          UserAttributes: [{ Name: 'email', Value: email }]
        }).promise();
        logger.info(`Usuario ${email} registrado exitosamente con sub: ${userSub}`);
        return {
          statusCode: 200,
          body: JSON.stringify({ message: 'User registered successfully. Please check your email for the confirmation code.', userId: userSub })
        };
      } catch (error) {
        logger.error(`Error en el registro para ${email}: ${error.message}`, { error });
        return { statusCode: 500, body: JSON.stringify({ message: error.message }) };
      }

    case 'confirmRegistration':
      try {
        logger.info(`Iniciando confirmación para ${email}`);
        await cognito.confirmSignUp({
          ClientId: COGNITO_CLIENT_ID,
          Username: email,
          ConfirmationCode: confirmationCode
        }).promise();
        logger.info(`Usuario ${email} confirmado exitosamente.`);
        return { statusCode: 200, body: JSON.stringify({ message: 'User confirmed successfully.' }) };
      } catch (error) {
        logger.error(`Error en la confirmación para ${email}: ${error.message}`, { error });
        return { statusCode: 500, body: JSON.stringify({ message: error.message }) };
      }

    case 'login':
      try {
        logger.info(`Iniciando inicio de sesión para ${email}`);
        const result = await cognito.initiateAuth({
          AuthFlow: 'USER_PASSWORD_AUTH',
          ClientId: COGNITO_CLIENT_ID,
          AuthParameters: {
            USERNAME: email,
            PASSWORD: password
          }
        }).promise();
        logger.info(`Usuario ${email} inició sesión exitosamente.`);
        return {
          statusCode: 200,
          body: JSON.stringify(result.AuthenticationResult)
        };
      } catch (error) {
        logger.error(`Error en el inicio de sesión para ${email}: ${error.message}`, { error });
        return { statusCode: 500, body: JSON.stringify({ message: error.message }) };
      }

    default:
      logger.warn('Acción no válida solicitada', { action });
      return { statusCode: 400, body: JSON.stringify({ message: 'Invalid action' }) };
  }
};