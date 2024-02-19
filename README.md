## Conceptos

data: En este folder estaria guardandose lo del RAG y Chromadb
docs: Es el folder donde se estan poniendo los data sources(pdf, excel)


## Como iniciar el servidor?
```
poetry install 
pip install -r requirements.txt
export OPENAI_API_KEY=sk-******
python3 app/server.py
```


## Como correr con docker

(Si estas usando mac)
```
docker build -t <DOCKER_REPO>/llm-betty:0.0.1-mac  .
docker run -ti --env OPENAI_API_KEY=sk-xxxxxxxx -p 8000:8000  benzzdan/llm-betty:0.0.1-mac
```

(Docker build para imagen para AWS)
docker buildx build -t benzzdan/llm-betty:0.0.1 --platform=linux/amd64 .
# Endpoints

http://localhost:8000/docs

http://localhost:8000/betty/stream


## Ejemplo de una llamada con curl:
```
curl http://localhost:8000/betty/stream -X POST -H "Content-Type: application/json" --data '{"input": {"question": "Hola Betty, me puedes mandar algun producto sobre cuchillos?"}}'
```

# Respuesta:
```
event: metadata
data: {"run_id": "5dcbc97d-b42e-49e5-b0c7-40d330eaf11f"}

event: data
data: {"question":"Hola Betty, me puedes mandar algun producto sobre cuchillos?","chat_history":[],"answer":"¡Hola! Claro, puedo ayudarte con eso. Tenemos los \"Cuchillos Anti Stick Betterware\" disponibles. Estos cuchillos cuentan con un recubrimiento antiadherente que evita que los alimentos se peguen, facilitando su corte. Además, son muy prácticos y duraderos. Tienen un precio original de $299, pero actualmente están en Mega Oferta y puedes llevártelos por $199 al comprar 1 producto marcado con etiqueta \"nuevo\". Si deseas ver cómo se utilizan, aquí te dejo un video: [link del video en YouTube](https://youtube.com/shorts/V-fEpJ-R2BE?si=nbYsFnKdAsSBAg1R). ¡Espero que te gusten!","source_documents":[{"page_content":"Producto\nVideo\nPrecio Original\nOferta\nDescripcion de oferta\nPrecio Oferta\n\n\n\\nCuchillos Anti Stick Betterware\nhttps://youtube.com/shorts/V-fEpJ-R2BE?si=nbYsFnKdAsSBAg1R\n299\nMega Oferta\nLlevate 1 prodcuto marcado con etiqueta \"nuevo\"\n199","metadata":{"category":"Table","file_directory":"./docs","filename":"Ofertas.xlsx","filetype":"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet","last_modified":"2024-02-14T17:11:34","page_name":"Videos","page_number":2,"source":"./docs/Ofertas.xlsx","text_as_html":"<table border=\"1\" class=\"dataframe\">\n  <tbody>\n    <tr>\n      <td>Producto</td>\n      <td>Video</td>\n      <td>Precio Original</td>\n      <td>Oferta</td>\n      <td>Descripcion de oferta</td>\n      <td>Precio Oferta</td>\n    </tr>\n    <tr>\n      <td>\\nCuchillos Anti Stick Betterware</td>\n      <td>https://youtube.com/shorts/V-fEpJ-R2BE?si=nbYsFnKdAsSBAg1R</td>\n      <td>299</td>\n      <td>Mega Oferta</td>\n      <td>Llevate 1 prodcuto marcado con etiqueta \"nuevo\"</td>\n      <td>199</td>\n    </tr>\n  </tbody>\n</table>"},"type":"Document"},{"page_content":"OFERTAS\n PORTADA\nMÁS\nINFORMACIÓNBIENVENIDO A NUESTRO MENÚ\nCONTIGO\nBAÑO\nCOCINA\nRECÁMARA\nBIENESTAR\nHIGIENE Y LIMPIEZA\nZONA DEL AHORRO\nHOGAR\nPRACTIMUEBLES","metadata":{"page":5,"source":"../../../docs/betterware.pdf"},"type":"Document"},{"page_content":"OFERTAS\n PORTADA\nMÁS\nINFORMACIÓNBIENVENIDO A NUESTRO MENÚ\nCONTIGO\nBAÑO\nCOCINA\nRECÁMARA\nBIENESTAR\nHIGIENE Y LIMPIEZA\nZONA DEL AHORRO\nHOGAR\nPRACTIMUEBLES","metadata":{"page":5,"source":"./docs/betterware.pdf"},"type":"Document"},{"page_content":"23571\nSet Better Ganchos Apilables\n$900 / 50 piezas\n$549\nAl comprar   productos\ndel catálogo\nAcero, Terciopelo y PVC. Soporta. 2 kg. 45 x 24 cm c/u. \nIncluye 10 apiladores de gancho.INCLUYE\n50 GANCHOSIncluye \n10 ganchos \npara apilar\n25  +  25  =  50\nOFERTAS\n MENÚnuevo","metadata":{"page":0,"source":"../../../docs/betterware.pdf"},"type":"Document"},{"page_content":"23571\nSet Better Ganchos Apilables\n$900 / 50 piezas\n$549\nAl comprar   productos\ndel catálogo\nAcero, Terciopelo y PVC. Soporta. 2 kg. 45 x 24 cm c/u. \nIncluye 10 apiladores de gancho.INCLUYE\n50 GANCHOSIncluye \n10 ganchos \npara apilar\n25  +  25  =  50\nOFERTAS\n MENÚnuevo","metadata":{"page":0,"source":"./docs/betterware.pdf"},"type":"Document"},{"page_content":"Apila para guardar\nRellena el agua sin \nretirar los contenedores\nEléctrico. 800 Watts. Polipropileno, Policarbonato y \nAcero inoxidable. 27 x 22 x 41 cm. Incluye 3 contenedores de 3 litros c/u y 1 contenedor de 1 litro. \ntemporizador60\nMINLITROS9Incluye tazónCOCINA  \nSALUDABLE\nCON VAPOR24502\nTri Vaporera \nInox\n$1,500\n$599\nAl comprar 1 producto\nmarcado así \nMENÚ\n OFERTASHÍPER OFERTA","metadata":{"page":4,"source":"./docs/betterware.pdf"},"type":"Document"}]}
```

## Documentacion adicional 

### Como obtener el historial del chat?

Como podemos ver a continuacion, utlizando un loop interno podemos iniciar el chat_history vacio, y despues ir agregandole la respuesta y mensajes el usuario:

```
chat_history = []
while True:
    # this prints to the terminal, and waits to accept an input from the user
    query = input('Prompt: ')
    # give us a way to exit the script
    if query == "exit" or query == "quit" or query == "q":
        print('Exiting')
        sys.exit()
    # we pass in the query to the LLM, and print out the response. As well as
    # our query, the context of semantically relevant information from our
    # vector store will be passed in, as well as list of our chat history
    result = qa_chain.invoke({'question': query, 'chat_history': chat_history})
    print('Answer: ' + result['answer'])
    # we build up the chat_history list, based on our question and response
    # from the LLM, and the script then returns to the start of the loop
    # and is again ready to accept user input.
    chat_history.append((query, result['answer']))
```


Esta linea indica que siempre se le va a agregar el resultado y la pregunta del usuario al historial: 
```
    chat_history.append((query, result['answer']))
```


Esto se deberia de manejar mediante session store en la parte del codigo del front end. Ejemplo con streamlit:

```
def onclick_callback():
    human_prompt = st.session_state.human_prompt
    chat_history = st.session_state.history
    llm_response = st.session_state.conversation.invoke({
        'question': human_prompt,
        'chat_history': chat_history
    })
    st.session_state.history.append(
        Message("human", human_prompt)
    )

    #Search for the youtube video  link 
    regexp = re.compile(r'.*youtube.com')
    # if regexp.search(llm_response["answer"]):
    #     st.session_state.history.append(
    #         Message("ai", llm_response["answer"]))
    #     )
    # else:
    st.session_state.history.append(
        Message("ai", llm_response["answer"])
    )
```