# Encryption for WhatsApp Flow endpoints. WhatsApp encrypts each request with a fresh AES key,
# which it encrypts with our public key (uploaded to every WhatsApp number). We answer with the
# same AES key and the flipped IV. The key pair is made once and kept in the installation config.
module WhatsappFlows::Crypto
  KEY_NAME = 'CHATSSYNC_WHATSAPP_FLOW_KEY'.freeze
  OAEP = { 'rsa_padding_mode' => 'oaep', 'rsa_oaep_md' => 'sha256', 'rsa_mgf1_md' => 'sha256' }.freeze

  class DecryptError < StandardError; end

  module_function

  def private_key
    @private_key ||= OpenSSL::PKey::RSA.new(stored_pem || create_pem)
  end

  def public_pem
    private_key.public_key.to_pem
  end

  # Returns [request hash, aes key, iv].
  def decrypt(params)
    aes_key = private_key.decrypt(Base64.decode64(params[:encrypted_aes_key].to_s), OAEP)
    iv = Base64.decode64(params[:initial_vector].to_s)
    body = Base64.decode64(params[:encrypted_flow_data].to_s)
    cipher = OpenSSL::Cipher.new("aes-#{aes_key.bytesize * 8}-gcm").decrypt
    cipher.key = aes_key
    cipher.iv_len = iv.bytesize # WhatsApp uses a 16-byte IV
    cipher.iv = iv
    cipher.auth_tag = body[-16..]
    [JSON.parse(cipher.update(body[0...-16]) + cipher.final), aes_key, iv]
  rescue OpenSSL::PKey::PKeyError, OpenSSL::Cipher::CipherError, JSON::ParserError, ArgumentError, TypeError => e
    raise DecryptError, e.message
  end

  def encrypt(response, aes_key, iv)
    cipher = OpenSSL::Cipher.new("aes-#{aes_key.bytesize * 8}-gcm").encrypt
    cipher.key = aes_key
    cipher.iv_len = iv.bytesize
    cipher.iv = iv.bytes.map { |byte| byte ^ 0xFF }.pack('C*')
    Base64.strict_encode64(cipher.update(response.to_json) + cipher.final + cipher.auth_tag)
  end

  def stored_pem
    ENV.fetch('WHATSAPP_FLOW_PRIVATE_KEY', nil).presence || InstallationConfig.find_by(name: KEY_NAME)&.value.presence
  end

  def create_pem
    pem = OpenSSL::PKey::RSA.generate(2048).to_pem
    InstallationConfig.create!(name: KEY_NAME, value: pem, locked: true)
    pem
  end
end
