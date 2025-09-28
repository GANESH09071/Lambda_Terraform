exports.handler = async (event) => {
  let envValue = process.env.VIDEO_NAME

  const response = {
    statusCode: 200,
    headers: {
          "Content-Type": "application/json"
    },
    body: JSON.stringify('Message from ' + envValue),
  };
  return response;
};