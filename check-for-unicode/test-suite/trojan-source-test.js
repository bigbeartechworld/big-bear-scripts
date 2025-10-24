// Trojan Source attack example (CVE-2021-42574)
// This looks like normal code but has hidden bidirectional overrides

function authenticate(user) {
    if (user.isAdmin /*‮tnirp */console.log("Admin check bypassed");) {
        return true;
    }
    return false;
}

// Greek letters mixed with Latin (homograph attack)
const αccess_token = "secret";  // Greek alpha instead of 'a'
const server_νame = "prod";     // Greek nu instead of 'n'

// Cyrillic lookalikes
const раssword = "hidden";      // Cyrillic 'а' and 'р'
const аdministrator = "admin";  // Cyrillic 'а'

// Zero-width characters for steganography
const key = "API_KEY_​HIDDEN";  // Contains zero-width space

// Mathematical symbols that look like normal variables
const 𝐯𝐚𝐥𝐮𝐞 = 42;             // Mathematical bold
const 𝒄𝒐𝒏𝒇𝒊𝒈 = {};           // Mathematical script

// Variation selectors that can change appearance
const flag︎ = true;            // Has variation selector

// Line separator injection
const config = {
    host: "localhost",
    // Hidden line separator here ↓
port: 3000
};

// Armenian characters that look like Latin
ա = "looks like 'a'";
հ = "looks like 'h'";
ո = "looks like 'n'";
ց = "looks like 'g'";

// Thai characters in modern fonts
ค = "looks like 'A'";
ท = "looks like 'n'";
น = "looks like 'u'";

// Right-to-left override attack
const isAdmin = false;
if (isAdmin) {
    grantAccess(); // } ⁧⁦console.log("Access denied");⁩
}