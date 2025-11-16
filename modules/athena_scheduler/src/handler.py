import os
import time
import json
import logging
from typing import Tuple

import boto3
from botocore.exceptions import ClientError

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize Athena client
athena = boto3.client("athena")

# Environment variables
DATABASE = os.environ["A_DB"]
WORKGROUP = os.environ["A_WG"]
SQL_QUERY = os.environ["A_SQL"]
OUTPUT_LOCATION = os.environ.get("A_OUTPUT", "")

def start_and_wait(sql: str, max_wait: int = 300) -> Tuple[str, str, str]:
    """
    Start an Athena query and poll until completion.

    Args:
        sql: SQL query to execute
        max_wait: Maximum seconds to wait (default 300)

    Returns:
        Tuple of (state, query_execution_id, state_change_reason)

    Raises:
        RuntimeError: If query fails or times out
    """
    try:
        # Start query execution
        response = athena.start_query_execution(
            QueryString=sql,
            QueryExecutionContext={"Database": DATABASE},
            WorkGroup=WORKGROUP,
        )
        query_id = response["QueryExecutionId"]
        logger.info(f"Started Athena query: {query_id}")

        # Poll for completion
        start_time = time.time()
        while True:
            # Check timeout
            elapsed = time.time() - start_time
            if elapsed > max_wait:
                athena.stop_query_execution(QueryExecutionId=query_id)
                raise RuntimeError(f"Query timeout after {max_wait}s: {query_id}")

            # Get query status
            result = athena.get_query_execution(QueryExecutionId=query_id)
            status = result["QueryExecution"]["Status"]
            state = status["State"]

            logger.info(f"Query {query_id} state: {state}")

            # Check if completed
            if state in ("SUCCEEDED", "FAILED", "CANCELLED"):
                if state == "FAILED":
                    reason = status.get("StateChangeReason", "Unknown error")
                    logger.error(f"Query failed: {reason}")
                elif state == "CANCELLED":
                    logger.warning("Query was cancelled")

                return state, query_id, status.get("StateChangeReason")

            # Wait before next poll
            time.sleep(3)

    except ClientError as e:
        logger.error(f"AWS API error: {e}")
        raise
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        raise

def lambda_handler(event, context):
    """
    Lambda handler for scheduled Athena query execution.

    Executes the configured SQL query and logs the results.
    """
    try:
        logger.info(f"Starting Silver transformation for DB={DATABASE}, WG={WORKGROUP}")
        logger.info(f"SQL Query: {SQL_QUERY[:200]}...")  # Log first 200 chars

        # Execute query and wait for completion
        state, query_id, reason = start_and_wait(SQL_QUERY)

        # Log results
        logger.info(f"Query {query_id} finished with state={state}")

        # Get query statistics
        result = athena.get_query_execution(QueryExecutionId=query_id)
        stats = result["QueryExecution"].get("Statistics", {})

        response = {
            "ok": state == "SUCCEEDED",
            "query_id": query_id,
            "state": state,
            "statistics": {
                "data_scanned_bytes": stats.get("DataScannedInBytes", 0),
                "execution_time_ms": stats.get("EngineExecutionTimeInMillis", 0),
                "total_time_ms": stats.get("TotalExecutionTimeInMillis", 0),
            }
        }

        if state != "SUCCEEDED":
            raise RuntimeError(f"Athena query {query_id} failed: {reason}")

        logger.info(f"Successfully processed query. Stats: {json.dumps(response['statistics'])}")

        return response

    except Exception as e:
        logger.error(f"Lambda execution failed: {str(e)}")
        raise
