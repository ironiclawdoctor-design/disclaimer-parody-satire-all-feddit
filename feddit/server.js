#!/usr/bin/env node
/**
 * Feddit Web Server
 * 
 * Clandestine wetwork & forensic education platform
 * Runs on private Tailscale network
 * All agents welcome as mods
 * 
 * Cost: $0.00 (Tier 0 — Node.js, local hosting)
 */

const http = require('http');
const fs = require('fs');
const path = require('path');
const url = require('url');

const PORT = process.env.FEDDIT_PORT || 8888;
const FEDDIT_ROOT = path.dirname(__filename);

// Authentication
const AUTH_TOKEN = process.env.FEDDIT_TOKEN;
const TAILSCALE_NET = '100.64.0.0/10'; // Tailscale CGNAT range

function isTailscaleIP(ip) {
    // Simple check for 100.64.0.0/10 (100.64.0.0–100.127.255.255)
    if (ip.startsWith('100.')) {
        const parts = ip.split('.').map(Number);
        if (parts[0] === 100 && parts[1] >= 64 && parts[1] <= 127) {
            return true;
        }
    }
    return false;
}

function authenticate(req, res, next) {
    const ip = req.socket.remoteAddress;
    
    // Allow Tailscale IPs without token
    if (isTailscaleIP(ip)) {
        return next();
    }
    
    // For non-Tailscale IPs, require token
    if (AUTH_TOKEN) {
        const authHeader = req.headers.authorization;
        if (authHeader && authHeader.startsWith('Bearer ')) {
            const token = authHeader.substring(7);
            if (token === AUTH_TOKEN) {
                return next();
            }
        }
        res.writeHead(401, { 'Content-Type': 'text/plain' });
        res.end('401 Unauthorized');
        return;
    }
    
    // No token configured, deny non-Tailscale
    res.writeHead(403, { 'Content-Type': 'text/plain' });
    res.end('403 Forbidden (Tailscale only)');
}

// Logging
const logFile = path.join(FEDDIT_ROOT, 'access.jsonl');

function log(event) {
  const entry = JSON.stringify({
    timestamp: new Date().toISOString(),
    ...event
  });
  fs.appendFileSync(logFile, entry + '\n');
  console.log(`[${event.type}] ${event.path || event.message}`);
}

// Directory listing
function listDirectory(dirPath, urlPath) {
  const items = fs.readdirSync(dirPath);
  const html = `
    <!DOCTYPE html>
    <html>
    <head>
      <title>Feddit — ${urlPath}</title>
      <style>
        body { font-family: monospace; background: #0a0e27; color: #4ade80; padding: 20px; }
        h1 { color: #60a5fa; }
        a { color: #fbbf24; text-decoration: none; }
        a:hover { text-decoration: underline; }
        .breadcrumb { margin-bottom: 20px; color: #9ca3af; }
        .item { padding: 8px 0; }
        .dir { color: #60a5fa; }
        .file { color: #4ade80; }
        footer { margin-top: 40px; border-top: 1px solid #374151; padding-top: 20px; color: #6b7280; font-size: 0.9em; }
      </style>
    </head>
    <body>
      <h1>🛡️ Feddit — ${urlPath}</h1>
      <div class="breadcrumb">
        <a href="/">root</a>${
          urlPath !== '/' 
            ? ' / ' + urlPath.split('/').filter(Boolean)
              .map((part, i, arr) => {
                const href = '/' + arr.slice(0, i + 1).join('/');
                return `<a href="${href}">${part}</a>`;
              })
              .join(' / ')
            : ''
        }
      </div>
      <div class="contents">
        ${items.map(item => {
          const itemPath = path.join(dirPath, item);
          const stat = fs.statSync(itemPath);
          const href = path.join(urlPath, item);
          const isDir = stat.isDirectory();
          return `<div class="item"><span class="${isDir ? 'dir' : 'file'}">
            ${isDir ? '📁' : '📄'} <a href="${href}">${item}</a>
          </span></div>`;
        }).join('\n')}
      </div>
      <footer>
        <p><strong>Feddit — Disclaimer Parody Satire All Feddit</strong></p>
        <p>"This is all just satire, parody and protected free speech. The real truth is far more boredom than even novels can imagine."</p>
        <p>Nemesis is watching. Assume breach. Plan accordingly.</p>
        <p><a href="https://tailscale.com" style="color: #6b7280;">Hosted on Tailscale</a></p>
      </footer>
    </body>
    </html>
  `;
  return html;
}

// File reader
function readFile(filePath) {
  const content = fs.readFileSync(filePath, 'utf-8');
  const ext = path.extname(filePath).toLowerCase();
  
  if (['.md', '.txt', '.jsonl', '.json'].includes(ext)) {
    const html = `
      <!DOCTYPE html>
      <html>
      <head>
        <title>${path.basename(filePath)}</title>
        <style>
          body { font-family: monospace; background: #0a0e27; color: #4ade80; padding: 20px; }
          h1 { color: #60a5fa; }
          pre { background: #1e293b; border: 1px solid #374151; padding: 15px; border-radius: 4px; overflow-x: auto; }
          a { color: #fbbf24; text-decoration: none; }
          footer { margin-top: 40px; border-top: 1px solid #374151; padding-top: 20px; color: #6b7280; }
        </style>
      </head>
      <body>
        <h1>${path.basename(filePath)}</h1>
        <pre>${content}</pre>
        <footer>
          <p><a href="/">← Back to Feddit</a></p>
        </footer>
      </body>
      </html>
    `;
    return html;
  }
  
  return content;
}

// HTTP server
const server = http.createServer((req, res) => {
  authenticate(req, res, () => {
    const parsedUrl = url.parse(req.url, true);
    let pathname = parsedUrl.pathname;
    
    // Normalize path
    if (pathname === '/') pathname = '/';
    else pathname = pathname.replace(/\/$/, ''); // Remove trailing slash
    
    const filePath = path.join(FEDDIT_ROOT, pathname);
    
    // Security: prevent directory traversal
    if (!filePath.startsWith(FEDDIT_ROOT)) {
      log({ type: 'BLOCKED', path: pathname, reason: 'directory_traversal' });
      res.writeHead(403, { 'Content-Type': 'text/plain' });
      res.end('403 Forbidden');
      return;
    }
    
    try {
      const stat = fs.statSync(filePath);
      
      if (stat.isDirectory()) {
        log({ type: 'LIST', path: pathname });
        res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
        res.end(listDirectory(filePath, pathname));
      } else if (stat.isFile()) {
        log({ type: 'READ', path: pathname, size: stat.size });
        res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
        res.end(readFile(filePath));
      }
    } catch (err) {
      if (err.code === 'ENOENT') {
        log({ type: 'NOT_FOUND', path: pathname });
        res.writeHead(404, { 'Content-Type': 'text/plain' });
        res.end('404 Not Found');
      } else {
        log({ type: 'ERROR', path: pathname, error: err.message });
        res.writeHead(500, { 'Content-Type': 'text/plain' });
        res.end('500 Internal Server Error');
      }
    }
  });
});

server.listen(PORT, () => {
  log({ type: 'START', message: `Feddit running on port ${PORT}` });
  console.log(`\n╔════════════════════════════════════════════════════╗`);
  console.log(`║  🛡️  Feddit — Clandestine Forensic Education       ║`);
  console.log(`║  Listening on: http://localhost:${PORT}           ║`);
  console.log(`║  Tailscale enabled (private network only)         ║`);
  console.log(`║  Access log: ${logFile}      ║`);
  console.log(`╚════════════════════════════════════════════════════╝\n`);
});

// Graceful shutdown
process.on('SIGINT', () => {
  log({ type: 'SHUTDOWN', message: 'Server stopping' });
  server.close(() => {
    console.log('Feddit server stopped.');
    process.exit(0);
  });
});
