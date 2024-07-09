from decouple import config

# bot info
BOT_TOKEN = config('bot_token')
ADMIN_CHATID = config('admin_chatid')
LANGUAGE = config('language')

# db info
DB_ADDRESS = config('db_address')