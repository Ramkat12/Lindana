from openai import OpenAI

# Create the OpenAI client once
client = OpenAI(api_key="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")  # <-- Replace with your real key

def chat_with_gpt(prompt):
    """Send a prompt to GPT and return its reply."""
    response = client.chat.completions.create(
        model="gpt-3.5-turbo",  # Change to "gpt-4.1" if you want GPT-4.1
        messages=[
            {"role": "system", "content": "You are a helpful assistant."},
            {"role": "user", "content": prompt}
        ]
    )
    return response.choices[0].message.content



if __name__ == "__main__":
    print("Type 'exit' or 'quit' to end the chat.")
    while True:
        user_input = input("You: ")
        if user_input.lower() in ["exit", "quit"]:
            break
        response = chat_with_gpt(user_input)
        print(f"GPT: {response}")


