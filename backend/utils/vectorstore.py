import chromadb

# Kết nối tới container chromadb trong mạng lưới Docker (host là tên service)
client = chromadb.HttpClient(host="chromadb", port=8000)
collection = client.get_or_create_collection("chunks")

def add_chunk(chunk_id, text, embedding, metadata):
    collection.add(
        documents=[text],
        metadatas=[metadata], 
        embeddings=[embedding],
        ids=[str(chunk_id)]
    )