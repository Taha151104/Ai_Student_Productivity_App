// index.js (Node.js backend)
const nodemailer = require('nodemailer');

const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: 'bc230200766mta@vu.edu.pk',
    pass: 'dzea pafj rytm zsfc', // Your 16-letter App Password
  },
});

async function sendDirectEmail(studentMessage) {
  if (!studentMessage || !studentMessage.trim()) return;

  const mailOptions = {
    from: '"Student App Support" <bc230200766mta@vu.edu.pk>',
    to: 'bc230200766mta@vu.edu.pk',
    subject: '🎯 New Student Support Ticket',
    text: `A student left a message: ${studentMessage}`,
    html: `<h3>New Support Request</h3><p><strong>Message:</strong> ${studentMessage}</p>`,
  };

  try {
    const info = await transporter.sendMail(mailOptions);
    console.log('Message sent: %s', info.messageId);
    return true;
  } catch (error) {
    console.error('Error sending email:', error);
    return false;
  }
}

module.exports = { sendDirectEmail };