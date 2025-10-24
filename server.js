import express from "express";
import cors from "cors";
import multer from "multer";
import { v4 as uuidv4 } from "uuid";
import fs from "fs";
import path from "path";

const app = express();
const PORT = process.env.PORT || 5000;

app.use(cors({ origin: "*" }));
app.use(express.json());

// Storage setup for uploaded voices
const upload = multer({ dest: "uploads/" });

// In-memory job tracking
const jobs = new Map();

/**
 * POST /api/generate
 * Creates a new video generation job
 */
app.post("/api/generate", upload.single("voice_file"), (req, res) => {
  const { script, language, length, quality, voice_type, mood } = req.body;
  const jobId = uuidv4();

  console.log("🎬 New video generation request:");
  console.log({ script, language, length, quality, voice_type, mood });

  // Simulate backend processing job
  jobs.set(jobId, { status: "processing", progress: 0, result: null });

  // fake async job
  simulateVideoJob(jobId);

  res.status(201).json({
    jobId,
    message: "Job queued successfully",
  });
});

/**
 * GET /api/status/:jobId
 * Check job status
 */
app.get("/api/status/:jobId", (req, res) => {
  const { jobId } = req.params;
  const job = jobs.get(jobId);

  if (!job) {
    return res.status(404).json({ error: "Job not found" });
  }

  res.json({
    jobId,
    status: job.status,
    progress: job.progress,
    result: job.result,
  });
});

/**
 * Simulate video generation progress
 */
function simulateVideoJob(jobId) {
  let progress = 0;
  const interval = setInterval(() => {
    const job = jobs.get(jobId);
    if (!job) {
      clearInterval(interval);
      return;
    }

    progress += Math.floor(Math.random() * 20) + 10;
    if (progress >= 100) {
      progress = 100;
      jobs.set(jobId, {
        status: "completed",
        progress,
        result: `https://cdn.visora.ai/videos/${jobId}.mp4`,
      });
      clearInterval(interval);
      console.log(`✅ Job ${jobId} completed!`);
    } else {
      jobs.set(jobId, {
        ...job,
        progress,
      });
      console.log(`Processing job ${jobId} - ${progress}%`);
    }
  }, 3000);
}

app.get("/", (req, res) => {
  res.send("Visora AI Backend is running ✅");
});

app.listen(PORT, () => {
  console.log(`🚀 Server live on port ${PORT}`);
});
