from ollamafreeapi import OllamaFreeAPI

# Create a client instance
client = OllamaFreeAPI()

# Get a response from a model
response = client.chat(
    model_name="llama3.3:70b",
    prompt="Tell me a joke",
    temperature=0.7
)

print(response)
