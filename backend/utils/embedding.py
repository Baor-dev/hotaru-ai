from sentence_transformers import SentenceTransformer

# Mô hình đa ngữ, hỗ trợ tiếng Việt tốt hơn rất nhiều so với bản L6-v2 tiếng Anh
model = SentenceTransformer('sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2')

def get_embedding(text):
    return model.encode(text).tolist()