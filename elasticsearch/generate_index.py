from elasticsearch import Elasticsearch
from datetime import datetime, timedelta, timezone
import random
import string

# Подключение к Elasticsearch с TLS
es = Elasticsearch(
    "https://localhost:9200",  
    basic_auth=("elastic", "password"),  
    verify_certs=False, 
    ssl_show_warn=False
)

index_name = "my_first_index"

# Описание структуры индекса (маппинг)
index_body = {
    "mappings": {
        "properties": {
            "timestamp": {"type": "date"},
            "number_field": {"type": "integer"},
            "string_field": {"type": "text"}
        }
    }
}

# Создаем индекс (если он не существует)
if not es.indices.exists(index=index_name):
    es.indices.create(index=index_name, body=index_body)
    print(f"Индекс '{index_name}' создан.")
else:
    print(f"Индекс '{index_name}' уже существует.")

# Функция для генерации случайной строки
def random_string(length=10):
    letters = string.ascii_lowercase
    return ''.join(random.choice(letters) for i in range(length))

# Генерация и отправка данных
for i in range(1000):  # Сгенерируем 1000 документов
    # 1. Случайный таймстамп (например, за последние 365 дней)
    random_days_ago = random.randint(0, 365)
    random_hours_ago = random.randint(0, 24)
    random_timestamp = datetime.now(timezone.utc) - timedelta(days=random_days_ago, hours=random_hours_ago)
    
    # 2. Случайное число (например, от 1 до 10000)
    random_number = random.randint(1, 10000)
    
    # 3. Случайная строка
    random_str = random_string()

    # Формируем документ
    doc = {
        "timestamp": random_timestamp,
        "number_field": random_number,
        "string_field": random_str
    }
    
    # Отправляем документ в Elasticsearch
    es.index(index=index_name, body=doc)

print("Данные успешно сгенерированы и отправлены в Elasticsearch!")