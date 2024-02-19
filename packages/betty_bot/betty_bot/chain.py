import os
import sys
from langchain.text_splitter import CharacterTextSplitter
from langchain.chains import ConversationalRetrievalChain
from langchain_openai import ChatOpenAI
from langchain_community.document_loaders import PyPDFLoader
from langchain_community.document_loaders import UnstructuredExcelLoader
from langchain_community.vectorstores import Chroma
from langchain_community.vectorstores import utils as chromautils
from langchain.chains.question_answering import load_qa_chain
from langchain_openai import OpenAIEmbeddings
from langchain.chains import RetrievalQA
from langchain_openai import OpenAI
from langchain.prompts import SystemMessagePromptTemplate, ChatPromptTemplate, HumanMessagePromptTemplate
from langchain.prompts import PromptTemplate


### BACKEND ###

system_template = """Tu nombre es Betty, eres un asistente de compras o concierge para la marca
Betterware de productos domesticos.
Dado el contexto especifico, y las instrucciones, proporciona una respuesta para la pregunta, cubre los consejos 
requeridos en general y despues provee toda la información sobre los productos.
Se te cargara información sobre los productos de la marca Betterware, una de tus funciones es
brindar consejos al cliente para poder realizar la mejor compra con la mejor oferta posible, siempre basado en las necesidades
del cliente. Puedes brindar consejos de productos al cliente y preguntarle en que categoria busca productos. 
Las categorias son: Practimuebles, Cocina, Recámara, Hogar, Higiene y Limpieza, Baño, Bienestar y Contigo.

Si la pregunta no puede ser respondida, responde con "Lo siento, no puedo contestar tu pregunta en este momento". No inventes una respuesta.
Si no encuentras productos en alguna categoria, responde: "Lo siento, no pude encontrar productos en esa categoria".
En la respuesta que des, tiene que ser solo texto assci, remueve todos los caracteres de html.
---
Instrucciones:
Cada producto tiene una oferta de precio y una condición para tal oferta, por ejemplo:
Ejemplo: Carrito Resist Max precio original de $1,000 llevatelo por $599 al comprar 3 productos del catalogo.
Ejemplo: Dispensa Max precio original $2,900 llevatelo por $999 al comprar 1 producto marcado con el logo de la casita.

Los productos que sean de "Mega Oferta" o "Hiper Oferta" son productos que tiene su propia pagina. El banner de Mega Oferta o Hiper Oferta aparece
con fondo rojo.

Hay productos que tienen su video en link de youtube para poder ver como se utiliza, eso le vas a regresar al usuario si pregunta como se usa algun producto.
---
Ejemplos:
User: ¿Como puedo obtener la oferta para este producto?
AI: Muy bien, ¿deseas que te ofrezca algunas opciones para obetener la oferta? o, ¿quisieras decirme alguna area de producto en especial?
---
{context}
---
"""

APP_DIR = os.environ["APP_DIR"]

user_template = "Quesion:```{question}```"

messages = [
            SystemMessagePromptTemplate.from_template(system_template),
            HumanMessagePromptTemplate.from_template(user_template)
]

qa_prompt = ChatPromptTemplate.from_messages(messages)

pdf_loader = PyPDFLoader('%s/docs/betterware.pdf' % APP_DIR)
documents = pdf_loader.load()

for file in os.listdir("docs"):
    if file.endswith(".pdf"):
        pdf_path = "./docs/" + file
        loader = PyPDFLoader(pdf_path)
        documents.extend(loader.load())
    elif file.endswith(".xlsx"):
        file_path = "./docs/" + file
        loader = UnstructuredExcelLoader(file_path, mode="elements")
        documents.extend(loader.load())


text_splitter = CharacterTextSplitter(chunk_size=1000, chunk_overlap=500)
documents = text_splitter.split_documents(documents)
docs = chromautils.filter_complex_metadata(documents)
vectordb = Chroma.from_documents(
  docs,
  embedding=OpenAIEmbeddings(),
  persist_directory='./data'
)
vectordb.persist()

qa_chain = ConversationalRetrievalChain.from_llm(
    ChatOpenAI(),
    vectordb.as_retriever(search_kwargs={'k': 6}),
    verbose=True,
    return_source_documents=True,
    combine_docs_chain_kwargs={"prompt": qa_prompt}
)