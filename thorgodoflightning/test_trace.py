import os
from langchain.callbacks.manager import tracing_v2_enabled
from langsmith import Client

# Set environment variables
os.environ["LANGSMITH_API_KEY"] = "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"
os.environ["LANGSMITH_TRACING"] = "true"
os.environ["LANGSMITH_PROJECT"] = "thorgodoflightning"
os.environ["LANGSMITH_ENDPOINT"] = "https://api.smith.langchain.com"

# Create client to verify connection
client = Client()

# Test simple trace
with tracing_v2_enabled(project_name="thorgodoflightning") as cb:
    print("Starting test trace")
    if cb.latest_run:
        cb.latest_run.add_metadata({
            "test": True,
            "message": "Hello World"
        })
        print(f"Created trace with ID: {cb.latest_run.id}")
    print("Ending test trace") 