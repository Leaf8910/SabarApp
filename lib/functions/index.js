// functions/index.js
// Firebase Cloud Function for handling email notifications

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');

admin.initializeApp();

// Configure your email service (Gmail example)
// You should use environment variables for sensitive data
const transporter = nodemailer.createTransporter({
  service: 'gmail',
  auth: {
    user: functions.config().gmail.email,
    pass: functions.config().gmail.password, // Use App Password for Gmail
  },
});

// Alternative: Using SendGrid
/*
const sgMail = require('@sendgrid/mail');
sgMail.setApiKey(functions.config().sendgrid.key);
*/

// Email templates
const emailTemplates = {
  welcome: {
    subject: 'Welcome to Islamic Prayer App! 🕌',
    html: (data) => `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background: linear-gradient(135deg, #4CAF50, #2E7D32); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }
          .content { background: #f9f9f9; padding: 30px; border-radius: 0 0 10px 10px; }
          .feature { display: flex; align-items: center; margin: 15px 0; }
          .feature-icon { width: 30px; height: 30px; margin-right: 15px; }
          .cta-button { background: #4CAF50; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block; margin: 20px 0; }
          .footer { text-align: center; margin-top: 30px; color: #666; font-size: 14px; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>🕌 Assalamu Alaikum, ${data.userName}!</h1>
            <p>Welcome to your spiritual journey with Islamic Prayer App</p>
          </div>
          <div class="content">
            <h2>May Allah bless your path! 🤲</h2>
            <p>We're thrilled to have you join our community of Muslims worldwide. Your account has been successfully created, and you're now ready to enhance your daily worship with our comprehensive Islamic tools.</p>
            
            <h3>🌟 What's Available for You:</h3>
            <div class="feature">
              <span class="feature-icon">⏰</span>
              <div>
                <strong>Accurate Prayer Times</strong><br>
                Get precise prayer times based on your location
              </div>
            </div>
            <div class="feature">
              <span class="feature-icon">🧭</span>
              <div>
                <strong>Qibla Direction</strong><br>
                Find the direction to Kaaba from anywhere
              </div>
            </div>
            <div class="feature">
              <span class="feature-icon">📖</span>
              <div>
                <strong>Quran Verses</strong><br>
                Read, listen, and practice pronunciation
              </div>
            </div>
            <div class="feature">
              <span class="feature-icon">📚</span>
              <div>
                <strong>Prayer Guidance</strong><br>
                Learn and perfect your prayer methods
              </div>
            </div>
            
            <p>
              <a href="https://your-app-url.com" class="cta-button">Open Islamic Prayer App</a>
            </p>
            
            <h3>📧 Important: Please Verify Your Email</h3>
            <p>To ensure you receive important updates and can recover your account if needed, please verify your email address using the verification link we've sent separately.</p>
            
            <h3>🎯 Next Steps:</h3>
            <ol>
              <li>Complete your profile setup to get personalized guidance</li>
              <li>Set your location for accurate prayer times</li>
              <li>Explore the Quran verses with audio recitation</li>
              <li>Check out the prayer guidance for your level</li>
            </ol>
            
            <p><strong>Need Help?</strong> If you have any questions or need assistance, don't hesitate to reach out to our support team. We're here to help make your spiritual journey smooth and meaningful.</p>
            
            <p>Barakallahu feeki and welcome to the community!</p>
            
            <div class="footer">
              <p>🕌 Islamic Prayer App Team<br>
              This email was sent to ${data.userEmail}<br>
              <small>If you didn't create this account, please ignore this email.</small></p>
            </div>
          </div>
        </div>
      </body>
      </html>
    `,
    text: (data) => `
      Assalamu Alaikum, ${data.userName}!
      
      Welcome to Islamic Prayer App! Your account has been successfully created.
      
      What's available for you:
      • Accurate Prayer Times based on your location
      • Qibla Direction finder
      • Quran Verses with audio recitation
      • Prayer Guidance for all levels
      
      Next steps:
      1. Complete your profile setup
      2. Set your location for prayer times
      3. Explore Quran verses
      4. Check prayer guidance
      
      Please verify your email address using the link we sent separately.
      
      Barakallahu feeki!
      Islamic Prayer App Team
    `,
  },

  email_verification: {
    subject: 'Please Verify Your Email - Islamic Prayer App',
    html: (data) => `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background: #2196F3; color: white; padding: 20px; text-align: center; border-radius: 10px 10px 0 0; }
          .content { background: #f9f9f9; padding: 30px; border-radius: 0 0 10px 10px; }
          .cta-button { background: #2196F3; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block; margin: 20px 0; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>📧 Email Verification Required</h1>
          </div>
          <div class="content">
            <p>Assalamu Alaikum ${data.userName},</p>
            
            <p>To complete your Islamic Prayer App account setup and ensure account security, please verify your email address.</p>
            
            <p><strong>Why verify your email?</strong></p>
            <ul>
              <li>Secure account recovery if you forget your password</li>
              <li>Receive important prayer time updates</li>
              <li>Get notified about new features</li>
              <li>Ensure account security</li>
            </ul>
            
            <p>If you haven't received the verification email from Firebase, please check your spam folder or click the button below to request a new one.</p>
            
            <p>
              <a href="https://your-app-url.com/verify" class="cta-button">Verify Email Address</a>
            </p>
            
            <p>If you didn't create this account, please ignore this email.</p>
            
            <p>Barakallahu feeki,<br>
            Islamic Prayer App Team</p>
          </div>
        </div>
      </body>
      </html>
    `,
    text: (data) => `
      Assalamu Alaikum ${data.userName},
      
      Please verify your email address to complete your Islamic Prayer App account setup.
      
      Email verification helps with:
      • Account security and recovery
      • Important prayer time updates
      • New feature notifications
      
      Visit: https://your-app-url.com/verify
      
      If you didn't create this account, please ignore this email.
      
      Barakallahu feeki,
      Islamic Prayer App Team
    `,
  },

  password_reset_confirmation: {
    subject: 'Password Reset Confirmation - Islamic Prayer App',
    html: (data) => `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background: #FF9800; color: white; padding: 20px; text-align: center; border-radius: 10px 10px 0 0; }
          .content { background: #f9f9f9; padding: 30px; border-radius: 0 0 10px 10px; }
          .alert { background: #fff3cd; border: 1px solid #ffeaa7; padding: 15px; border-radius: 6px; margin: 15px 0; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>🔒 Password Reset Requested</h1>
          </div>
          <div class="content">
            <p>Assalamu Alaikum ${data.userName},</p>
            
            <p>We received a request to reset your password for your Islamic Prayer App account (${data.userEmail}).</p>
            
            <div class="alert">
              <strong>⚠️ Security Notice:</strong> If you didn't request this password reset, please ignore this email. Your account remains secure.
            </div>
            
            <p><strong>What happens next:</strong></p>
            <ol>
              <li>Check your email for the password reset link from Firebase</li>
              <li>Click the link to create a new password</li>
              <li>Use the new password to sign in to your account</li>
            </ol>
            
            <p><strong>Security Tips:</strong></p>
            <ul>
              <li>Choose a strong password with at least 8 characters</li>
              <li>Include uppercase, lowercase, numbers, and special characters</li>
              <li>Don't reuse passwords from other accounts</li>
              <li>Keep your password private and secure</li>
            </ul>
            
            <p>If you need further assistance, please don't hesitate to contact our support team.</p>
            
            <p>May Allah protect your account,<br>
            Islamic Prayer App Team</p>
          </div>
        </div>
      </body>
      </html>
    `,
    text: (data) => `
      Assalamu Alaikum ${data.userName},
      
      We received a password reset request for your Islamic Prayer App account (${data.userEmail}).
      
      If you didn't request this, please ignore this email.
      
      Check your email for the Firebase password reset link to create a new password.
      
      Security tips:
      • Use a strong password (8+ characters)
      • Include uppercase, lowercase, numbers, and symbols
      • Don't reuse passwords
      
      May Allah protect your account,
      Islamic Prayer App Team
    `,
  },

  profile_completion: {
    subject: 'Complete Your Islamic Journey Setup 🌟',
    html: (data) => `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background: #9C27B0; color: white; padding: 20px; text-align: center; border-radius: 10px 10px 0 0; }
          .content { background: #f9f9f9; padding: 30px; border-radius: 0 0 10px 10px; }
          .cta-button { background: #9C27B0; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block; margin: 20px 0; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>🌟 Complete Your Profile</h1>
          </div>
          <div class="content">
            <p>Assalamu Alaikum ${data.userName},</p>
            
            <p>We noticed you haven't completed your profile setup yet. Completing your profile helps us provide you with personalized Islamic guidance and accurate prayer times.</p>
            
            <p><strong>🎯 What you'll get with a complete profile:</strong></p>
            <ul>
              <li><strong>Personalized Guidance:</strong> Content tailored to your religious background</li>
              <li><strong>Accurate Prayer Times:</strong> Based on your exact location</li>
              <li><strong>Custom Experience:</strong> App features adapted to your level</li>
              <li><strong>Better Support:</strong> More helpful assistance when needed</li>
            </ul>
            
            <p>It only takes 2 minutes to complete your profile:</p>
            <ol>
              <li>Add your name and age</li>
              <li>Select your religious background</li>
              <li>Choose your country for prayer times</li>
            </ol>
            
            <p>
              <a href="https://your-app-url.com/profile-setup" class="cta-button">Complete My Profile</a>
            </p>
            
            <p>Your spiritual journey is important to us, and we want to make sure you get the most out of Islamic Prayer App.</p>
            
            <p>Barakallahu feeki,<br>
            Islamic Prayer App Team</p>
          </div>
        </div>
      </body>
      </html>
    `,
    text: (data) => `
      Assalamu Alaikum ${data.userName},
      
      Complete your profile to get personalized Islamic guidance and accurate prayer times.
      
      Benefits of completing your profile:
      • Personalized content for your religious level
      • Accurate prayer times for your location
      • Custom app experience
      • Better support when needed
      
      It takes just 2 minutes:
      1. Add your name and age
      2. Select religious background
      3. Choose your country
      
      Visit: https://your-app-url.com/profile-setup
      
      Barakallahu feeki,
      Islamic Prayer App Team
    `,
  },
};

// Cloud Function to process email notifications
exports.processEmailNotification = functions.firestore
  .document('email_notifications/{emailId}')
  .onCreate(async (snap, context) => {
    const emailData = snap.data();
    
    try {
      console.log('Processing email notification:', emailData.type);
      
      const template = emailTemplates[emailData.template];
      if (!template) {
        throw new Error(`Template ${emailData.template} not found`);
      }
      
      const mailOptions = {
        from: `"Islamic Prayer App" <${functions.config().gmail.email}>`,
        to: emailData.to,
        subject: template.subject,
        html: template.html(emailData.data),
        text: template.text(emailData.data),
      };
      
      // Send email using nodemailer
      await transporter.sendMail(mailOptions);
      
      // Update document status
      await snap.ref.update({
        status: 'sent',
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      console.log(`Email sent successfully to ${emailData.to}`);
      
    } catch (error) {
      console.error('Error sending email:', error);
      
      // Update document with error status
      await snap.ref.update({
        status: 'failed',
        error: error.message,
        failedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });

// Alternative function for SendGrid
/*
exports.processEmailNotificationSendGrid = functions.firestore
  .document('email_notifications/{emailId}')
  .onCreate(async (snap, context) => {
    const emailData = snap.data();
    
    try {
      const template = emailTemplates[emailData.template];
      if (!template) {
        throw new Error(`Template ${emailData.template} not found`);
      }
      
      const msg = {
        to: emailData.to,
        from: 'noreply@your-domain.com',
        subject: template.subject,
        html: template.html(emailData.data),
        text: template.text(emailData.data),
      };
      
      await sgMail.send(msg);
      
      // Update document status
      await snap.ref.update({
        status: 'sent',
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      console.log(`Email sent successfully via SendGrid to ${emailData.to}`);
      
    } catch (error) {
      console.error('Error sending email via SendGrid:', error);
      
      await snap.ref.update({
        status: 'failed',
        error: error.message,
        failedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });
*/

// Function to clean up old email records (optional)
exports.cleanupOldEmails = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async (context) => {
    const cutoff = new Date();
    cutoff.setDate(cutoff.getDate() - 30); // Delete emails older than 30 days
    
    const oldEmails = await admin.firestore()
      .collection('email_notifications')
      .where('createdAt', '<', cutoff)
      .get();
    
    const batch = admin.firestore().batch();
    oldEmails.docs.forEach(doc => {
      batch.delete(doc.ref);
    });
    
    await batch.commit();
    console.log(`Cleaned up ${oldEmails.size} old email records`);
  });

// Function to send welcome email with delay (optional)
exports.sendDelayedWelcomeEmail = functions.auth.user().onCreate(async (user) => {
  // Wait 5 minutes before sending welcome email to give user time to complete profile
  setTimeout(async () => {
    try {
      const userDoc = await admin.firestore()
        .collection('users')
        .doc(user.uid)
        .get();
      
      if (userDoc.exists && !userDoc.data().profileCompleted) {
        // Send profile completion reminder
        await admin.firestore()
          .collection('email_notifications')
          .add({
            to: user.email,
            template: 'profile_completion',
            data: {
              userName: user.displayName || user.email.split('@')[0],
              userEmail: user.email,
              userId: user.uid,
              appName: 'Islamic Prayer App',
            },
            status: 'pending',
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            type: 'profile_reminder',
          });
      }
    } catch (error) {
      console.error('Error sending delayed welcome email:', error);
    }
  }, 5 * 60 * 1000); // 5 minutes delay
});