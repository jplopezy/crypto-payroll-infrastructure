// Crypto Payroll API - Main Application
const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const compression = require('compression');
const rateLimit = require('express-rate-limit');
const multer = require('multer');
const AWS = require('aws-sdk');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const winston = require('winston');
require('dotenv').config();

// Initialize Express app
const app = express();
const PORT = process.env.PORT || 8080;

// Configure AWS
AWS.config.update({
  region: process.env.AWS_REGION || 'us-east-1'
});

const s3 = new AWS.S3();
const secretsManager = new AWS.SecretsManager();

// Configure logging
const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console(),
    new winston.transports.File({ filename: 'logs/error.log', level: 'error' }),
    new winston.transports.File({ filename: 'logs/combined.log' })
  ]
});

// Security middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'", "'unsafe-inline'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", "data:", "https:"],
    },
  },
}));

app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000'],
  credentials: true
}));

app.use(compression());

// Rate limiting
const limiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 15 * 60 * 1000, // 15 minutes
  max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS) || 100,
  message: 'Too many requests from this IP, please try again later.'
});
app.use(limiter);

// Body parsing middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Configure multer for file uploads
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB limit
  },
  fileFilter: (req, file, cb) => {
    // Only allow encrypted files
    if (file.mimetype === 'application/octet-stream' || file.originalname.endsWith('.enc')) {
      cb(null, true);
    } else {
      cb(new Error('Only encrypted files are allowed'), false);
    }
  }
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    version: process.env.npm_package_version || '1.0.0'
  });
});

// Get secret from AWS Secrets Manager
async function getSecret(secretName) {
  try {
    const result = await secretsManager.getSecretValue({ SecretId: secretName }).promise();
    return JSON.parse(result.SecretString);
  } catch (error) {
    logger.error(`Error retrieving secret ${secretName}:`, error);
    throw error;
  }
}

// Upload file to S3
async function uploadToS3(bucketName, key, fileBuffer, metadata = {}) {
  try {
    const params = {
      Bucket: bucketName,
      Key: key,
      Body: fileBuffer,
      Metadata: metadata,
      ServerSideEncryption: 'AES256'
    };
    
    const result = await s3.upload(params).promise();
    logger.info(`File uploaded to S3: ${result.Location}`);
    return result;
  } catch (error) {
    logger.error('Error uploading to S3:', error);
    throw error;
  }
}

// Log transaction to S3
async function logTransaction(transactionData) {
  try {
    const logKey = `transactions/${Date.now()}-${crypto.randomUUID()}.json`;
    const logData = {
      timestamp: new Date().toISOString(),
      transactionId: crypto.randomUUID(),
      ...transactionData
    };
    
    await uploadToS3(
      process.env.S3_BUCKET_NAME,
      logKey,
      Buffer.from(JSON.stringify(logData, null, 2)),
      { 'Content-Type': 'application/json' }
    );
    
    logger.info('Transaction logged successfully');
    return logData;
  } catch (error) {
    logger.error('Error logging transaction:', error);
    throw error;
  }
}

// Simulate external API call (Fireblocks-like)
async function callExternalSigningAPI(walletAddress, amount, apiKey) {
  try {
    // This would be a real API call to Fireblocks or similar service
    const response = {
      transactionId: crypto.randomUUID(),
      status: 'completed',
      walletAddress,
      amount,
      timestamp: new Date().toISOString(),
      signature: crypto.randomBytes(32).toString('hex')
    };
    
    logger.info(`External API call successful for wallet ${walletAddress}`);
    return response;
  } catch (error) {
    logger.error('External API call failed:', error);
    throw error;
  }
}

// Process payroll file
async function processPayrollFile(fileBuffer) {
  try {
    // In a real implementation, this would decrypt and parse the file
    // For demo purposes, we'll simulate the processing
    const mockPayrollData = [
      { walletAddress: '0x1234567890123456789012345678901234567890', amount: '100.50' },
      { walletAddress: '0x0987654321098765432109876543210987654321', amount: '250.75' }
    ];
    
    logger.info(`Processing payroll file with ${mockPayrollData.length} entries`);
    return mockPayrollData;
  } catch (error) {
    logger.error('Error processing payroll file:', error);
    throw error;
  }
}

// API Routes

// Upload and process payroll file
app.post('/api/payroll/upload', upload.single('payrollFile'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No file uploaded' });
    }

    logger.info(`Received payroll file: ${req.file.originalname}`);

    // Process the payroll file
    const payrollData = await processPayrollFile(req.file.buffer);

    // Get external API key from Secrets Manager
    const secrets = await getSecret(process.env.EXTERNAL_API_SECRET_NAME);
    const apiKey = secrets.api_key;

    // Process each payroll entry
    const results = [];
    for (const entry of payrollData) {
      try {
        // Call external signing API
        const apiResponse = await callExternalSigningAPI(
          entry.walletAddress,
          entry.amount,
          apiKey
        );

        // Log successful transaction
        await logTransaction({
          walletAddress: entry.walletAddress,
          amount: entry.amount,
          apiResponse,
          fileName: req.file.originalname
        });

        results.push({
          walletAddress: entry.walletAddress,
          amount: entry.amount,
          status: 'success',
          transactionId: apiResponse.transactionId
        });
      } catch (error) {
        logger.error(`Failed to process wallet ${entry.walletAddress}:`, error);
        results.push({
          walletAddress: entry.walletAddress,
          amount: entry.amount,
          status: 'failed',
          error: error.message
        });
      }
    }

    res.json({
      message: 'Payroll processing completed',
      totalEntries: payrollData.length,
      successful: results.filter(r => r.status === 'success').length,
      failed: results.filter(r => r.status === 'failed').length,
      results
    });

  } catch (error) {
    logger.error('Error processing payroll upload:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get transaction logs
app.get('/api/transactions', async (req, res) => {
  try {
    const params = {
      Bucket: process.env.S3_BUCKET_NAME,
      Prefix: 'transactions/',
      MaxKeys: 100
    };

    const result = await s3.listObjectsV2(params).promise();
    const transactions = [];

    for (const obj of result.Contents || []) {
      try {
        const fileData = await s3.getObject({
          Bucket: process.env.S3_BUCKET_NAME,
          Key: obj.Key
        }).promise();
        
        const transaction = JSON.parse(fileData.Body.toString());
        transactions.push(transaction);
      } catch (error) {
        logger.error(`Error reading transaction file ${obj.Key}:`, error);
      }
    }

    res.json({
      transactions: transactions.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp))
    });

  } catch (error) {
    logger.error('Error retrieving transactions:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Wallet authentication endpoint (for the mini-challenge)
app.post('/api/auth/challenge', async (req, res) => {
  try {
    const { walletAddress } = req.body;
    
    if (!walletAddress || !walletAddress.match(/^0x[a-fA-F0-9]{40}$/)) {
      return res.status(400).json({ error: 'Invalid wallet address' });
    }

    // Generate challenge
    const nonce = crypto.randomBytes(32).toString('hex');
    const timestamp = Date.now();
    const challenge = `BAX Authentication: ${nonce}:${timestamp}:${walletAddress}`;

    // Store challenge (in production, use Redis)
    // For demo, we'll just return it
    res.json({
      challenge,
      expiresIn: 300 // 5 minutes
    });

  } catch (error) {
    logger.error('Error generating challenge:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Verify wallet signature
app.post('/api/auth/verify', async (req, res) => {
  try {
    const { walletAddress, signature, challenge } = req.body;

    // In production, verify the signature using ethers.js or web3.js
    // For demo purposes, we'll simulate verification
    const isValid = signature && signature.length === 132; // Basic validation

    if (!isValid) {
      return res.status(401).json({ error: 'Invalid signature' });
    }

    // Generate JWT token
    const secrets = await getSecret(process.env.JWT_SECRET_NAME);
    const token = jwt.sign(
      { walletAddress, timestamp: Date.now() },
      secrets.signing_key,
      { expiresIn: `${process.env.JWT_EXPIRATION_HOURS || 24}h` }
    );

    res.json({
      token,
      walletAddress,
      expiresIn: process.env.JWT_EXPIRATION_HOURS || 24
    });

  } catch (error) {
    logger.error('Error verifying signature:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Error handling middleware
app.use((error, req, res, next) => {
  logger.error('Unhandled error:', error);
  res.status(500).json({ error: 'Internal server error' });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({ error: 'Endpoint not found' });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  logger.info(`Crypto Payroll API server running on port ${PORT}`);
  logger.info(`Environment: ${process.env.NODE_ENV || 'development'}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM received, shutting down gracefully');
  process.exit(0);
});

process.on('SIGINT', () => {
  logger.info('SIGINT received, shutting down gracefully');
  process.exit(0);
});

module.exports = app;
