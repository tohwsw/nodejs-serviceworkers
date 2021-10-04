# nodejs-serviceworkers

This repo demonstrates how to adapt Service workers, which typically runs in the browser, to run server side using Node/Express. The app.js contains wrapper that invokes servicework.js

It makes use of the node-fetch library over here https://www.npmjs.com/package/node-fetch

```
npm install node-fetch@2
```

To run the application
```
node app.js
```

Test the application using the following urls:
http://localhost:3000/sw/hello
http://localhost:3000/sw/rewrite
http://localhost:3000/sw/redirect
http://localhost:3000/sw/setheaders
