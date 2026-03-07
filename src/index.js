const express = require('express');
const helmet = require('helmet'); // Helps secure your app by setting various HTTP headers
require('dotenv').config();      // Loads environment variables from a .env file

const app = express();

// Use the PORT from your .env file, or default to 3000
const PORT = process.env.PORT || 3000;

// --- MIDDLEWARE ---
app.use(helmet());           // Layer 1: Security Headers
app.use(express.json());     // Layer 2: Secure JSON parsing

// --- ROUTES ---

// Main Route: Default endpoint
app.get('/', (req, res) => {
  res.send('Welcome to Project Sentinel Core. Explore /health or /tasks.');
});

// Health Check: Essential for Kubernetes monitoring in Phase 5
app.get('/health', (req, res) => {
  res.status(200).json({ 
    status: 'Sentinel is active', 
    uptime: process.uptime(),
    timestamp: new Date().toISOString()
  });
});

// Task Route: The core logic for your task manager
app.get('/tasks', (req, res) => {
  res.json([
    { id: 1, task: "Setup Secure Pipeline", status: "In Progress" },
    { id: 2, task: "Harden Docker Image", status: "Pending" },
    { id: 3, task: "Configure AWS EKS", status: "Future" }
  ]);
});

// --- START SERVER ---
app.listen(PORT, () => {
  console.log(`🛡️ Project Sentinel Core is running on http://localhost:${PORT}`);
});