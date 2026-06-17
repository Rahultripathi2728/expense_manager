const sdk = require('node-appwrite');

module.exports = async function (context) {
  const { req, res, log, error } = context;

  log('Notification database trigger function invoked.');
  log(`Request body: ${req.bodyRaw || JSON.stringify(req.body)}`);

  let notification;
  try {
    notification = typeof req.body === 'string' ? JSON.parse(req.body) : req.body;
  } catch (e) {
    error('Failed to parse request body: ' + e.message);
    return res.json({ success: false, error: 'Invalid body JSON' });
  }

  // Check if we have a valid notification and target user
  if (!notification || !notification.userId) {
    error('Notification payload is missing userId.');
    return res.json({ success: false, error: 'Missing userId' });
  }

  const client = new sdk.Client()
    .setEndpoint(process.env.APPWRITE_FUNCTION_API_ENDPOINT)
    .setProject(process.env.APPWRITE_FUNCTION_PROJECT_ID)
    .setKey(process.env.APPWRITE_API_KEY || req.headers['x-appwrite-key']);

  const messaging = new sdk.Messaging(client);

  try {
    // Call Appwrite's native Messaging service to send a push notification
    // Appwrite will look up all registered push targets (device tokens) for this userId
    // and deliver it through FCM.
    const response = await messaging.createPush(
      sdk.ID.unique(),
      notification.title || 'New Notification', // Title
      notification.body || '',                 // Body
      [],                                      // Topics
      [notification.userId]                    // User Targets (Appwrite User ID)
    );

    log(`Successfully dispatched push notification to user: ${notification.userId}`);
    return res.json({ success: true, messageId: response.$id });
  } catch (e) {
    error(`Failed to send push notification to user ${notification.userId}: ` + e.message);
    return res.json({ success: false, error: e.message });
  }
};
