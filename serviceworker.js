const nodefetch = require('node-fetch'); //this lib defines some of the web api classes

//addEventListener('fetch', event => {
async function fetchHandler(event) { // this replaces the addEventListener in the serviceworker
  event.respondWith(handleRequest(event.request))
  }

 async function getContent(uri) {
      let response = await nodefetch(uri);
      let data = await response.text()
      //console.log("data:" + data);
      return data;
    }
  
  async function handleRequest(request) {
  console.log(request.path);

  if (request.path.match(new RegExp('/sw/hello', 'g'))) {
   return new nodefetch.Response('Hello worker!', {
      headers: { 'content-type': 'text/plain' },
    })
  }
  else if (request.path.match(new RegExp('/sw/rewrite', 'g'))) {
    const uri = 'https://amazon.sg';
    console.log("About to call: " + uri);

    return new nodefetch.Response(await getContent(uri),{
      headers: { 'content-type': 'text/html;charset=UTF-8' },
      status: 200
    });
   }
   else if (request.path.match(new RegExp('/sw/redirect', 'g'))) {
    const uri = 'https://amazon.sg';
    console.log("About to call: " + uri);

    return new nodefetch.Response('',{
      headers: { 'content-type': 'text/html;charset=UTF-8'},
      status: 302,
      url: 'https://amazon.sg'
    });
   }
   else if (request.path.match(new RegExp('/sw/setheaders', 'g'))) {
    const newResponse = new nodefetch.Response('Hello worker!', {});
    newResponse.headers.append('Content-Type', 'image/jpeg');
    newResponse.headers.set('Content-Type', 'text/html');
    return newResponse;
   }


  }

  module.exports = { fetchHandler };