"""Load explicit visual-review exclusions without allowing validation/test edits."""
import json


def load_exclusions(path):
    report = json.loads(path.read_text(encoding='utf8'))
    if report['status'] != 'VISUALLY_REVIEWED_TRAIN_EXCLUSIONS':
        raise ValueError('Explicit visual training review required')
    result = {}
    for row in report['images']:
        digest = row['prepared_sha256']
        if (row['split'] != 'train' or row['source'] not in ('codingbear', 'sumn2u') or
                not row.get('reason') or 'group' not in row):
            raise ValueError('Exclusions require public train identity and reason')
        if len(digest) != 64 or any(c not in '0123456789abcdef' for c in digest):
            raise ValueError('Invalid reviewed image SHA256')
        if digest in result:
            raise ValueError('Duplicate reviewed exclusion')
        result[digest] = row
    return result


def validate_exclusion(row, reviewed):
    for field in ('split', 'source', 'group'):
        if row[field] != reviewed[field]:
            raise ValueError('Reviewed exclusion identity/split mismatch: '+field)
    if row['split'] != 'train' or row['sha256'] != reviewed['prepared_sha256']:
        raise ValueError('Reviewed exclusion must match exact training image')
