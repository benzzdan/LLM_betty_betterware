from fastapi import FastAPI
from langserve import add_routes
from packages.betty_bot.betty_bot.chain import qa_chain


app = FastAPI(
    title="LangChain Server",
    version="1.0",
    description="API para servir a betty bot llm service",
)

add_routes(
    app,
    qa_chain,
    path="/betty",
)


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="localhost", port=8000)