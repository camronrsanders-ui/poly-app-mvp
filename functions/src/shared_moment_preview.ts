type SourceMessageRecord = Record<string, unknown>;

export function safeSharedMomentMessagePreview(
  data: SourceMessageRecord | undefined,
  conversationId: string,
): string {
  if (!data
      || data.conversationId !== conversationId
      || data.messageType !== 'text'
      || data.isDeleted === true) {
    return '';
  }
  return typeof data.text === 'string' ? data.text : '';
}
