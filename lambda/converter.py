import logging
import json
from currency_converter import CurrencyConverter
logger = logging.getLogger()
logger.setLevel(logging.INFO)



def lambda_handler(event, context):
    """
    The Lambda handler function that gets invoked when the API endpoint is hit
    """
    query_params = event.get('queryStringParameters', {})
    if not query_params:
        return {
            "statusCode": 400,
            "body": json.dumps({"error": f"Missing query string parameters"})
        }

    amount = query_params.get('amount')
    from_currency = query_params.get('from_currency')
    to_currency = query_params.get('to_currency')

    if not all([amount, from_currency, to_currency]):
        return {
            "statusCode": 400,
            "body": json.dumps({"error": "Missing required parameters: amount, from_currency, or from_currency"})
        }

    logger.info('## Input Parameters: %s, %s, %s', amount, from_currency, to_currency)
    try:
        res = convert_currency(amount, from_currency, to_currency)
        logger.info('## Currency result: %s', res)
        response = {
            "statusCode": 200,
            "body": json.dumps({'result': res}),
        }
    except Exception as e:
        logger.error('## Error occurred: %s', str(e))
        response = {
            "statusCode": 500,
            "body": json.dumps({"error": "Internal server error"})
        }

    logger.info('## Response returned: %s', response)
    return response

def convert_currency(amount: float, from_currency: str, to_currency: str) -> float:
    """
    Function to convert an amount from one currency to another
    """
    c = CurrencyConverter()
    res = c.convert(amount, from_currency, to_currency)
    logger.info('## Currency result from original: %s', res)
    return res