from ollamafreeapi import OllamaFreeAPI

# Create a client instance
client = OllamaFreeAPI()

# Specify the model you want to use
model_name = "llama3.2:latest"  # You can change this to any available model

# Get user input for the prompt
user_prompt = input("Enter your prompt: ")

# Get a response from the model
response = client.chat(
    model_name=model_name,
    prompt=user_prompt,
    temperature=0.7
)

# Print the response
print(response)
