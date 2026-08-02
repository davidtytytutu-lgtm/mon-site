const express = require("express");
const cors = require("cors");

const app = express();

const PORT = 9000;


// Configuration IA
const MODEL = "qwen2.5:0.5b";
const MAX_HISTORY = 10;


// Middleware
app.use(cors());
app.use(express.json());


// Mémoire des conversations
const users = new Map();


// Récupérer une mémoire utilisateur
function getHistory(id = "default") {

    if (!users.has(id)) {

        users.set(id, [

            {
                role: "system",
                content:
                `Tu es DavidBot, un assistant IA personnel créé par David.
Tu n'es pas ChatGPT, Claude ou une autre IA.
Tu utilises Ollama.
Si on te demande qui est ton créateur, réponds :
"J'ai été créé par David pour être un assistant IA personnel utilisant Ollama."
Tu réponds toujours en français, simplement et clairement.`
            }

        ]);

    }


    return users.get(id);

}



// Limiter la mémoire
function limitHistory(history) {


    if(history.length > MAX_HISTORY + 1){


        history.splice(
            1,
            history.length - (MAX_HISTORY + 1)
        );


    }


}




// Accueil
app.get("/", (req,res)=>{

    res.send(
        "🤖 DavidBot serveur streaming actif !"
    );

});




// Test
app.get("/chat",(req,res)=>{

    res.json({

        reply:"API DavidBot OK"

    });

});





// CHAT STREAMING
app.post("/chat", async(req,res)=>{


try {


    const message = req.body.message;

    const userId = req.body.user || "default";



    if(!message){

        return res.json({

            reply:"Message vide."

        });

    }



    const history =
    getHistory(userId);



    history.push({

        role:"user",

        content:message

    });



    limitHistory(history);





    const response = await fetch(

        "http://127.0.0.1:11434/api/chat",

        {

            method:"POST",

            headers:{

                "Content-Type":"application/json"

            },


            body:JSON.stringify({

                model:MODEL,

                messages:history,

                stream:true,

                keep_alive:"30m",


                options:{


                    temperature:0.3,

                    num_predict:150,

                    num_thread:4


                }


            })


        }

    );





    if(!response.ok){

        throw new Error(
            "Erreur Ollama : "+response.status
        );

    }





    // Configuration streaming

    res.setHeader(
        "Content-Type",
        "text/event-stream"
    );


    res.setHeader(
        "Cache-Control",
        "no-cache"
    );


    res.setHeader(
        "Connection",
        "keep-alive"
    );





    const reader =
    response.body.getReader();



    const decoder =
    new TextDecoder();



    let fullAnswer = "";





    while(true){


        const {
            done,
            value
        } =
        await reader.read();




        if(done)
            break;




        const text =
        decoder.decode(value);




        const lines =
        text.split("\n");





        for(const line of lines){



            if(!line.trim())
                continue;



            try {



                const json =
                JSON.parse(line);




                const token =
                json.message?.content;



                if(token){



                    fullAnswer += token;



                    res.write(

                        `data: ${JSON.stringify({

                            token:token

                        })}\n\n`

                    );


                }




            }
            catch(e){

                // morceau incomplet ignoré

            }



        }



    }





    // Sauvegarde réponse complète

    history.push({

        role:"assistant",

        content:fullAnswer

    });






    res.write(

        `data: ${JSON.stringify({

            done:true

        })}\n\n`

    );



    res.end();





}
catch(error){



    console.error(
        "Erreur:",
        error
    );



    res.status(500).json({

        reply:
        "Erreur IA : "+error.message

    });



}



});





// Lancement serveur

app.listen(PORT,()=>{


    console.log(
        `🤖 DavidBot streaming lancé sur http://localhost:${PORT}`
    );


});
