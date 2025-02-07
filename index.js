const functions = require('@google-cloud/functions-framework');

functions.http('helloWorld', (req, res) => {
  res.send({
    message: 'Hello from Cloud Functions!'
  });
}); 