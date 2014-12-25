module shaker;

import std.stdio;

extern (C) {
  int crypto_box_keypair(ref ubyte pk[32], ref ubyte sk[32]);
  int crypto_sign_keypair(ref ubyte pk[32], ref ubyte sk[64]);
  int crypto_box_easy(ubyte*, ubyte*, ulong, ref ubyte[24], ref ubyte[32], ref ubyte[64]);
  int crypto_sign(ubyte*, ulong*, ubyte*, ulong, ref ubyte[64]);
  int crypto_sign_open(ubyte*, ulong*, ubyte *, ulong, ref ubyte[32]);
  int crypto_box_open_easy(ubyte*, ubyte*, ulong, ref ubyte[24], ref ubyte[32], ref ubyte[64]);
}

struct SignedMessage {
  ubyte[] data;

  // signedBy returns true if this messages was signed by the keypair, signer.
  bool signedBy(KeyPair signer) {
    ubyte output[] = new ubyte[this.data.length - 64];
    ulong length;
    int valid = crypto_sign_open(&output[0], &length, &this.data[0], this.data.length, signer.public_key);
    return (valid == 0);
  }
}

struct EncryptedMessage {
  ubyte[] message;
  ubyte[24] nonce;
}

class KeyPair {
  ubyte public_key[32];
  ubyte secret_key[64];

  this() {
    crypto_sign_keypair(this.public_key, this.secret_key);
  }

  this(ubyte pubk[32], ubyte secretk[64]) {
    this.public_key = pubk;
    this.secret_key = secretk;
  }

  SignedMessage sign(string data) {
    return this.sign(cast(ubyte[])data);
  }

  SignedMessage sign(ubyte[] data) {
    ubyte output[] = new ubyte[data.length + 64];
    ulong length;
    crypto_sign(&output[0], &length, &data[0], data.length, this.secret_key);
    return SignedMessage(output);
  }

  EncryptedMessage encrypt(string data, KeyPair other) {
    return this.encrypt(cast(ubyte[])data, other);
  }

  EncryptedMessage encrypt(ubyte[] data, KeyPair other) {
    ubyte output[] = new ubyte[data.length + 16];
    ubyte nonce[24]; // TODO
    crypto_box_easy(&output[0], &data[0], data.length, nonce, other.public_key, this.secret_key);
    return EncryptedMessage(output, nonce);
  }

  ubyte[] decrypt(EncryptedMessage msg, KeyPair other) {
    ubyte output[] = new ubyte[msg.message.length - 16];
    crypto_box_open_easy(&output[0], &msg.message[0], msg.message.length, msg.nonce, other.public_key, this.secret_key); 
    return output;
  }

}

unittest {
  KeyPair bob = new KeyPair;
  KeyPair alice = new KeyPair;

  // Test that key signing works
  SignedMessage data = bob.sign("hey alice this is bob!");
  assert(data.signedBy(bob));
  assert(!data.signedBy(alice));
}

