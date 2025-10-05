from http.server import HTTPServer, BaseHTTPRequestHandler
import sys

class HealthHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path in ['/health', '/ready']:
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(b'{"status": "healthy"}')
        else:
            self.send_response(404)
            self.end_headers()
    
    def log_message(self, format, *args):
        # Silent logging
        pass

if __name__ == '__main__':
    print("Health check server starting on port 8080...", flush=True)
    try:
        server = HTTPServer(('0.0.0.0', 8080), HealthHandler)
        print("Health check server ready", flush=True)
        server.serve_forever()
    except Exception as e:
        print(f"Error starting health server: {e}", flush=True)
        sys.exit(1)
