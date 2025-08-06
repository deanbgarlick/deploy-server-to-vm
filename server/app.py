from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
import logging
import google.cloud.logging
from datetime import datetime
import sys
import uuid

# Configure standard logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    stream=sys.stdout
)
logger = logging.getLogger(__name__)

# Initialize Google Cloud Logging
try:
    client = google.cloud.logging.Client()
    client.setup_logging()
    logger.info("Successfully initialized Google Cloud Logging")
except Exception as e:
    logger.warning(f"Failed to initialize Google Cloud Logging: {e}")

app = FastAPI(title="Hello World API")

@app.middleware("http")
async def log_requests(request: Request, call_next):
    # Generate a unique request ID
    request_id = str(uuid.uuid4())
    start_time = datetime.utcnow()
    
    # Log incoming request
    logger.info(
        "Request received",
        extra={
            "request_id": request_id,
            "timestamp": start_time.isoformat(),
            "request_path": request.url.path,
            "request_method": request.method,
            "client_ip": request.client.host if request.client else None,
            "user_agent": request.headers.get("user-agent"),
            "query_params": str(request.query_params),
            "request_headers": dict(request.headers)
        }
    )
    
    try:
        response = await call_next(request)
        end_time = datetime.utcnow()
        duration = (end_time - start_time).total_seconds()
        
        # Log response with combined request context
        logger.info(
            "Response sent",
            extra={
                "request_id": request_id,
                "timestamp": end_time.isoformat(),
                "duration_seconds": duration,
                "status_code": response.status_code,
                # Request context
                "request_path": request.url.path,
                "request_method": request.method,
                "client_ip": request.client.host if request.client else None,
                # Response details
                "response_headers": dict(response.headers),
                "response_status": "success" if response.status_code < 400 else "error"
            }
        )
        return response
        
    except Exception as e:
        end_time = datetime.utcnow()
        duration = (end_time - start_time).total_seconds()
        
        # Log error response
        logger.error(
            "Request failed",
            extra={
                "request_id": request_id,
                "timestamp": end_time.isoformat(),
                "duration_seconds": duration,
                "error": str(e),
                "error_type": type(e).__name__,
                # Request context
                "request_path": request.url.path,
                "request_method": request.method,
                "client_ip": request.client.host if request.client else None
            }
        )
        raise

@app.get("/")
async def read_root():
    logger.info("Handling root endpoint request")
    return {"message": "Hello World"}

@app.get("/health")
async def health_check():
    logger.info("Health check requested")
    return JSONResponse(
        status_code=200,
        content={"status": "healthy", "timestamp": datetime.utcnow().isoformat()}
    )

if __name__ == "__main__":
    import uvicorn
    logger.info("Starting FastAPI server")
    uvicorn.run(app, host="0.0.0.0", port=8000)
