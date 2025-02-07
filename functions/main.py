import firebase_admin
from firebase_admin import credentials, firestore
from firebase_functions import https_fn
from firebase_functions.params import StringParam

# Initialize Firebase Admin SDK
cred = credentials.Certificate('./service-account.json')
firebase_admin.initialize_app(cred)
db = firestore.client()

@https_fn.on_request()
def update_document(req: https_fn.Request) -> https_fn.Response:
    """HTTP Cloud Function to update a Firestore document.
    
    Expected JSON body format:
    {
        "collection": "collection_name",
        "document_id": "doc_id",
        "data": {
            "field1": "value1",
            "field2": "value2"
        }
    }
    """
    try:
        # Get request JSON data
        request_json = req.get_json()
        
        if not request_json:
            return https_fn.Response("No JSON data provided", status=400)
            
        collection = request_json.get('collection')
        document_id = request_json.get('document_id')
        data = request_json.get('data')
        
        if not all([collection, document_id, data]):
            return https_fn.Response("Missing required fields", status=400)
            
        # Update the document
        doc_ref = db.collection(collection).document(document_id)
        doc_ref.update(data)
        
        return https_fn.Response(f"Document {document_id} updated successfully")
        
    except Exception as e:
        return https_fn.Response(f"Error: {str(e)}", status=500)

@https_fn.on_request()
def analyze_health(req: https_fn.Request) -> https_fn.Response:
    """HTTP Cloud Function to check service health.
    Returns basic health status and Firebase connection state.
    """
    try:
        # Simple test query to verify Firestore connection
        db.collection('_health_check').limit(1).get()
        return https_fn.Response({"status": "healthy", "database": "connected"})
    except Exception as e:
        return https_fn.Response(
            {"status": "unhealthy", "error": str(e)}, 
            status=500
        ) 