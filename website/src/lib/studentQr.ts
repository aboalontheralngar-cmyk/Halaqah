const STUDENT_QR_PREFIX = 'HALAQAH:STUDENT:1:';

export interface DecodedStudentQr {
  token: string;
  legacyStudentId: boolean;
}

export function encodeStudentQr(qrToken: string): string {
  return `${STUDENT_QR_PREFIX}${qrToken.trim()}`;
}

export function decodeStudentQr(value: string): DecodedStudentQr | null {
  const normalized = value.trim();
  if (normalized.startsWith(STUDENT_QR_PREFIX)) {
    const token = normalized.slice(STUDENT_QR_PREFIX.length).trim();
    return token ? { token, legacyStudentId: false } : null;
  }

  // Cards printed by the first web release contained the student UUID only.
  const uuidPattern =
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  return uuidPattern.test(normalized)
    ? { token: normalized, legacyStudentId: true }
    : null;
}
