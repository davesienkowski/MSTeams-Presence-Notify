"""
MS Teams Presence Notification Light - Main Service

This is the main entry point for the computer service that:
1. Authenticates with Microsoft Graph API
2. Polls Teams presence status
3. Serves status data to PyPortal via HTTP
"""

import os
import sys
import time
import logging
from typing import Optional
from dotenv import load_dotenv

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class TeamsPresenceService:
    """Main service for MS Teams Presence monitoring"""

    def __init__(self):
        """Initialize the service"""
        load_dotenv()

        self.tenant_id = os.getenv('AZURE_TENANT_ID')
        self.client_id = os.getenv('AZURE_CLIENT_ID')
        self.client_secret = os.getenv('AZURE_CLIENT_SECRET')
        self.server_host = os.getenv('SERVER_HOST', '0.0.0.0')
        self.server_port = int(os.getenv('SERVER_PORT', 8080))
        self.polling_interval = int(os.getenv('POLLING_INTERVAL', 30))

        self._validate_config()

        self.current_status = {
            'availability': 'Unknown',
            'activity': 'Unknown',
            'color': '#FFFFFF'
        }

    def _validate_config(self):
        """Validate required configuration"""
        if not all([self.tenant_id, self.client_id, self.client_secret]):
            logger.error("Missing required Azure AD configuration")
            logger.error("Please set AZURE_TENANT_ID, AZURE_CLIENT_ID, and AZURE_CLIENT_SECRET")
            sys.exit(1)

    def run(self):
        """Run the service"""
        logger.info("MS Teams Presence Service starting...")
        logger.info(f"Server will listen on {self.server_host}:{self.server_port}")
        logger.info(f"Polling interval: {self.polling_interval} seconds")

        # TODO: Initialize authentication
        # TODO: Start background status polling
        # TODO: Start HTTP server

        logger.info("Service initialization complete")
        logger.warning("Full implementation pending - service skeleton created")


def main():
    """Main entry point"""
    try:
        service = TeamsPresenceService()
        service.run()
    except KeyboardInterrupt:
        logger.info("Service stopped by user")
    except Exception as e:
        logger.error(f"Service error: {e}", exc_info=True)
        sys.exit(1)


if __name__ == "__main__":
    main()
