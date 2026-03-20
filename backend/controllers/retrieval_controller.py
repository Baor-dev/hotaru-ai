def search_chunks(query, notebook_id, document_ids=None, top_k=8):
    embedding = get_embedding(query)
    filter = {"notebook_id": str(notebook_id)}
    if document_ids:
        filter["document_id"] = {"$in": [str(doc_id) for doc_id in document_ids]}
    results = collection.query(
        query_embeddings=[embedding],
        n_results=top_k,
        where=filter
    )
    return results["documents"], results["metadatas"], results["ids"]