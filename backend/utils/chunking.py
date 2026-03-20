from underthesea import sent_tokenize

def chunk_text(text, chunk_size=20, overlap=5):
    """
    Chunk Vietnamese text using underthesea sent_tokenize.
    - text: String of extracted document text.
    - chunk_size: Number of sentences in each chunk.
    - overlap: Number of sentences overlapped between chunks.
    Returns: List of chunk strings.
    """
    sentences = sent_tokenize(text)
    chunks = []
    idx = 0
    while idx < len(sentences):
        chunk = " ".join(sentences[idx : idx + chunk_size])
        chunks.append(chunk)
        idx += chunk_size - overlap  # overlap for context continuity
    return chunks