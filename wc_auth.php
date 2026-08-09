<?php
/**
 * wc_auth.php — Финальная защита по Device ID (через POST-данные)
 */
$request_method = $_SERVER['REQUEST_METHOD'];
$user_agent = isset($_SERVER['HTTP_USER_AGENT']) ? strtolower($_SERVER['HTTP_USER_AGENT']) : '';
$is_bot = preg_match('/(whatsapp|telegram|facebookexternalhit|twitterbot|slack|discord)/i', $user_agent);

$code = '';
$device_id = '';

if ($request_method === 'POST') {
    // Безопасное получение данных через POST (не через заголовки)
    $code = isset($_POST['code']) ? trim(strtolower($_POST['code'])) : '';
    $device_id = isset($_POST['device_id']) ? trim($_POST['device_id']) : '';
} else {
    $code = isset($_GET['code']) ? trim(strtolower($_GET['code'])) : '';
}

if (empty($code)) {
    if ($request_method === 'POST') {
        header('Content-Type: application/json');
        echo json_encode(['success' => false, 'message' => 'Код не может быть пустым.']);
    } else {
        http_response_code(400);
        echo 'Код доступа не указан.';
    }
    exit;
}

// -------------------------------------------------------------------------
// 1. Читаем keys.json и базу активаций
// -------------------------------------------------------------------------
$json_path = __DIR__ . '/keys.json';
$activations_path = __DIR__ . '/activations.json';

if (!file_exists($json_path)) {
    if ($request_method === 'POST') {
        header('Content-Type: application/json');
        echo json_encode(['success' => false, 'message' => 'Файл keys.json не найден.']);
    } else {
        http_response_code(500);
        echo 'Ошибка конфигурации.';
    }
    exit;
}

$master_config = json_decode(file_get_contents($json_path), true);
if (json_last_error() !== JSON_ERROR_NONE) {
    if ($request_method === 'POST') {
        header('Content-Type: application/json');
        echo json_encode(['success' => false, 'message' => 'Ошибка синтаксиса в keys.json.']);
    } else {
        http_response_code(500);
        echo 'Ошибка конфигурации.';
    }
    exit;
}

if (!file_exists($activations_path)) {
    file_put_contents($activations_path, json_encode([]));
}
$activations = json_decode(file_get_contents($activations_path), true);

// -------------------------------------------------------------------------
// 2. Ищем проект
// -------------------------------------------------------------------------
$master_config_lower = array_change_key_case($master_config, CASE_LOWER);
if (!isset($master_config_lower[$code])) {
    if ($request_method === 'POST') {
        header('Content-Type: application/json');
        echo json_encode(['success' => false, 'message' => "Код '{$code}' не найден в keys.json."]);
    } else {
        http_response_code(404);
        echo 'Код доступа недействителен.';
    }
    exit;
}

$project = $master_config_lower[$code];

// -------------------------------------------------------------------------
// 3. ПРОВЕРКА АКТИВАЦИЙ (только для POST-запросов)
// -------------------------------------------------------------------------
$max_devices = isset($project['max_devices']) ? intval($project['max_devices']) : 1;

if (!isset($activations[$code])) {
    $activations[$code] = [];
}

if (!$is_bot && $request_method === 'POST') {
    // Если не передали device_id — блокируем сразу
    if (empty($device_id)) {
        header('Content-Type: application/json');
        echo json_encode(['success' => false, 'message' => 'Ошибка идентификации устройства. Обновите плеер.']);
        exit;
    }

    if (!in_array($device_id, $activations[$code])) {
        if (count($activations[$code]) >= $max_devices) {
            header('Content-Type: application/json');
            echo json_encode(['success' => false, 'message' => "Лимит активаций исчерпан (макс. {$max_devices} устройств)."]);
            exit;
        }
        $activations[$code][] = $device_id;
        file_put_contents($activations_path, json_encode($activations, JSON_PRETTY_PRINT));
    }
}

// -------------------------------------------------------------------------
// 4. Отдаём превью для ботов
// -------------------------------------------------------------------------
if ($is_bot && $request_method !== 'POST') {
    $preview_image = __DIR__ . '/model/preview_' . basename($project['model'] ?? '', '.glb') . '.jpg';
    if (!file_exists($preview_image)) {
        $preview_image = __DIR__ . '/default_preview.jpg';
    }
    
    header('Content-Type: text/html; charset=utf-8');
    echo <<<HTML
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta property="og:title" content="{$project['title']}">
    <meta property="og:description" content="3D-проект барбекю комплекса от студии Печных дел Мастер.">
    <meta property="og:image" content="{$preview_image}">
    <meta property="og:url" content="https://pechnik-novosib.ru/3d-player/player.html#{$code}">
    <title>{$project['title']}</title>
</head>
<body>
    <h1>{$project['title']}</h1>
    <p>Перейдите по ссылке для просмотра 3D-модели.</p>
</body>
</html>
HTML;
    exit;
}

// -------------------------------------------------------------------------
// 5. Отдаём GLB-файл
// -------------------------------------------------------------------------
$model_file = __DIR__ . '/model/' . ($project['model'] ?? '');
if (!file_exists($model_file)) {
    if ($request_method === 'POST') {
        header('Content-Type: application/json');
        echo json_encode(['success' => false, 'message' => 'Файл модели не найден: ' . basename($model_file)]);
    } else {
        http_response_code(500);
        echo 'Ошибка: файл модели отсутствует.';
    }
    exit;
}

if ($request_method === 'POST') {
    header('Content-Type: application/octet-stream');
    header('Content-Disposition: attachment; filename="' . basename($model_file) . '"');
    header('Content-Length: ' . filesize($model_file));
    header('X-Project-Title: ' . rawurlencode($project['title'] ?? 'Проект'));
    header('X-Project-Logo: ' . rawurlencode($project['logo'] ?? ''));
    header('X-Project-Spec: ' . rawurlencode($project['spec'] ?? ''));
    header('X-Project-Tech: ' . rawurlencode($project['tech'] ?? ''));
    readfile($model_file);
    exit;
} else {
    echo "Код доступа '{$code}' подтверждён.";
    exit;
}
