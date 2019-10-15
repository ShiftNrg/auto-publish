/*
Dependencies:
npm install @peculiar/webcrypto
npm install text-encoder-lite
*/

const fs = require('fs');

const { Crypto } = require("@peculiar/webcrypto");
const crypto = new Crypto();

const TextEncoder = require('text-encoder-lite').TextEncoderLite;
const TextDecoder = require('text-encoder-lite').TextDecoderLite;

// Arguments
const args = process.argv.splice(process.execArgv.length + 2);
const pass = args[0] || "testing";
const source = args[1] || "source.tmp";
const target = args[2] || source + ".encrypted"

  function salt() {
    var fixed = [ 195, 78, 249, 203, 63, 36, 76, 84, 86, 202, 30, 92, 92, 89, 101, 53 ];
    var salt = new Uint8Array(fixed.length ? fixed : 16);
    if (!fixed.length) salt = crypto.getRandomValues(salt);

    return salt;
  }

  function ab2str(buf) {
	return new TextDecoder().decode(new Uint8Array(buf));
  }

  function str2ab(str) {
	return new TextEncoder("utf-8").encode(str);
  }

  function encrypt (data, pass, cb) {
    var vector = new Uint8Array(salt());
    crypto.subtle.digest({name: 'SHA-256'}, str2ab(pass)).then((res) => {
      crypto.subtle.importKey('raw', res, {name: 'AES-CBC'}, false, ['encrypt', 'decrypt']).then((key) => {
        crypto.subtle.encrypt({name: 'AES-CBC', iv: vector}, key, str2ab(data)).then((encrypted) => {
          cb(encrypted, vector);
        }).catch((err) => {
          console.error(err);
          cb(null);
        });
      })
    })
  }

  function decrypt (cypher, vector, pass, cb) {
    var cypher = new Uint8Array(cypher);
    var vector = new Uint8Array(vector);
    crypto.subtle.digest({name: 'SHA-256'}, str2ab(pass)).then((res) => {
      crypto.subtle.importKey('raw', res, {name: 'AES-CBC'}, false, ['encrypt', 'decrypt']).then((key) => {
        crypto.subtle.decrypt({name: 'AES-CBC', iv: vector}, key, cypher).then((decrypted) => {
          cb(decrypted);
        }).catch((err) => {
          console.error(err);
          cb(null);
        })
      })
    })
  }

  fs.readFile(source, null, function read(err, data) {
	if (err) {
		return console.log(err);
	}

	  encrypt(ab2str(data), pass, function(cypher, vector) {
		let buffer = Buffer.concat([vector, new Uint8Array(cypher)]);
		fs.writeFile(target, buffer, function(err) {
			if (err) {
				return console.log(err);
			}

			console.log('Written encrypted file to: ', target);

			// fs.readFile(target, null, function read(err, data) {
			// 	if (err) {
			// 		return console.log(err);
			// 	}

			//	cypher = data.slice(16);
			//	vector = data.slice(0, 16);
			// 	decrypt (cypher, vector, pass, function(decrypted) {
			// 		console.log(ab2str(decrypted));
			// 	});
			// });
		});
	});
  });

