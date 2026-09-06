type SourceMessageRecord = Record<string, unknown>;

export type SharedMomentMessagePreview = {
  text: string;
  senderUid: string;
};

export function safeSharedMomentMessagePreview(
  data: SourceMessageRecord | undefined,
  conversationId: string,
): SharedMomentMessagePreview {
  if (!data
      || data.conversationId !== conversationId
      || data.messageType !== 'text'
      || data.isDeleted === true) {
    return {text: '', senderUid: ''};
  }
  const text = typeof data.text === 'string' ? data.text : '';
  const senderUid = typeof data.senderUid === 'string' ? data.senderUid : '';
  if (!text || !senderUid) return {text: '', senderUid: ''};
  return {text, senderUid};
}
