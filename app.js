const express = require('express');
const port = process.env.PORT || 3000;
const app = express();


const sw = require('./serviceworker.js');


app.get('/sw/*', async (req,res) => {
  let ev = {
    request: req,
    respondWith: async function(responsePromise) {
      responsePromise.then(responseObject => { //callback
        console.log(responseObject.status);
        console.log(responseObject.url);
        console.log(responseObject.headers.get('Content-Type'));
        res.set('Content-type', responseObject.headers.get('Content-Type'));
        if(responseObject.url){
          res.location(responseObject.url);
        }
        res.status(responseObject.status).send(responseObject.body);
        
      });
    }
  };    

  await sw.fetchHandler(ev);  
});


app.listen(port);
console.log('Ready')        