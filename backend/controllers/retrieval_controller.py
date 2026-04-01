from backend.utils.embedding import get_embedding
from backend.utils.vectorstore import collection

def search_chunks(query, notebook_id, document_ids=None, top_k=8):
    embedding = get_embedding(query)[0]

    filter = {"notebook_id": str(notebook_id)}
    if document_ids:
        filter["document_id"] = {"$in": [str(doc_id) for doc_id in document_ids]}

    results = collection.query(
        query_embeddings=[embedding],
        n_results=top_k,
        where=filter
    )

    return [
        {
            "text": doc,
            "metadata": meta,
            "id": _id
        }
        for doc, meta, _id in zip(
            results["documents"][0],
            results["metadatas"][0],
            results["ids"][0]
        )
    ]