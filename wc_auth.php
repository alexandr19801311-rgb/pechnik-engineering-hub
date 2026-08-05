<?php
/**
 * wc_auth.php — Авторизация по ключу из keys.json (исправлен пробел в названии)
 */
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    exit;
}

$code = isset($_POST['code']) ? trim(strtolower($_POST['code'])) : '';
if (empty($code)) {
    header('Content-Type: application/json');
    echo json_encode(['success' => false, 'message' => 'Код не может быть пустым.']);
    exit;
}

// Читаем keys.json
$json_path = __DIR__ . '/keys.json';
if (!file_exists($json_path)) {
    header('Content-Type: application/json');
    echo json_encode(['success' => false, 'message' => 'Файл keys.json не найден.']);
    exit;
}

$master_config = json_decode(file_get_contents($json_path), true);
if (json_last_error() !== JSON_ERROR_NONE) {
    header('Content-Type: application/json');
    echo json_encode(['success' => false, 'message' => 'Ошибка синтаксиса в keys.json.']);
    exit;
}

// Поиск проекта (без учёта регистра)
$master_config_lower = array_change_key_case($master_config, CASE_LOWER);
if (!isset($master_config_lower[$code])) {
    header('Content-Type: application/json');
    echo json_encode(['success' => false, 'message' => "Код '{$code}' не найден в keys.json."]);
    exit;
}

$project = $master_config_lower[$code];

// Проверка наличия файла модели
$model_file = __DIR__ . '/model/' . ($project['model'] ?? '');
if (!file_exists($model_file)) {
    header('Content-Type: application/json');
    echo json_encode(['success' => false, 'message' => 'Файл модели не найден: ' . basename($model_file)]);
    exit;
}

// Отдаём GLB-файл с нужными заголовками
header('Content-Type: application/octet-stream');
header('Content-Disposition: attachment; filename="' . basename($model_file) . '"');
header('Content-Length: ' . filesize($model_file));

header('X-Project-Title: ' . rawurlencode($project['title'] ?? 'Проект'));
header('X-Project-Logo: ' . rawurlencode($project['logo'] ?? ''));
header('X-Project-Spec: ' . rawurlencode($project['spec'] ?? ''));
header('X-Project-Tech: ' . rawurlencode($project['tech'] ?? '')); // ← ВОТ ЭТА СТРОКА ОБЯЗАТЕЛЬНО ДОЛЖНА БЫТЬ

readfile($model_file);
exit;
