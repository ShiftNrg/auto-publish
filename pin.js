var shiftjs = require('../shift-js');

// Variables
var node = 'localhost';
var SHIFT = shiftjs.api({ testnet: true, port: 9405, node: node });
var secretPhrase = 'your secret phrase goes here';
var secondPhrase = false;

// Arguments
var args = process.argv.splice(process.execArgv.length + 2);
var hash = args[0] || "Qm";
var bytes = parseInt(args[1]) || 0;
var unpin = args[2] == 'true';
var parent = args[3].toString() || null;

// Create pin transaction
var account = SHIFT.getAddressFromSecret(secretPhrase);

// Generate and broadcast pin transaction
SHIFT.sendRequest('pins', {
	hash: hash, bytes: bytes, parent: parent, secret: secretPhrase, secondSecret: secondPhrase, type: (unpin ? 'unpin' : 'pin' )}, 
	function (data) {
		data.senderid = account.address;

		// Output to console
		console.log(JSON.stringify(data));
	}
);
