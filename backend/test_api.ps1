$baseUrl = "http://localhost:8080"

# 1. Register Dispatcher
Write-Host "Registering Dispatcher..."
try {
    $dispatcher = Invoke-RestMethod -Uri "$baseUrl/auth/register" -Method Post -Body (@{
            name     = "Dispatcher John"
            phone    = "1111"
            password = "pass"
            role     = "dispatcher"
        } | ConvertTo-Json) -ContentType "application/json" -ErrorAction Stop
    $dispatcher
}
catch {
    Write-Host "Dispatcher registration failed (maybe already exists): $_"
}

# 2. Login Dispatcher
Write-Host "Logging in Dispatcher..."
$loginRes = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method Post -Body (@{
        phone    = "1111"
        password = "pass"
    } | ConvertTo-Json) -ContentType "application/json"
$dispatcherToken = $loginRes.token
Write-Host "Dispatcher Token: $dispatcherToken"

# 3. Register Driver
Write-Host "Registering Driver..."
try {
    $driver = Invoke-RestMethod -Uri "$baseUrl/auth/register" -Method Post -Body (@{
            name     = "Driver Mike"
            phone    = "2222"
            password = "pass"
            role     = "driver"
        } | ConvertTo-Json) -ContentType "application/json" -ErrorAction Stop
    $driver
}
catch {
    Write-Host "Driver registration failed (maybe already exists): $_"
}

# 4. Login Driver
Write-Host "Logging in Driver..."
$driverLoginRes = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method Post -Body (@{
        phone    = "2222"
        password = "pass"
    } | ConvertTo-Json) -ContentType "application/json"
$driverToken = $driverLoginRes.token
$driverId = $driverLoginRes.user.id
Write-Host "Driver Token: $driverToken"
Write-Host "Driver ID: $driverId"

# 5. Create Order (Dispatcher)
Write-Host "Creating Order..."
$order = Invoke-RestMethod -Uri "$baseUrl/api/orders" -Method Post -Headers @{Authorization = "Bearer $dispatcherToken" } -Body (@{
        from_address = "Street A"
        to_address   = "Street B"
        comment      = "Fast please"
    } | ConvertTo-Json) -ContentType "application/json"
$order

# 6. List Orders (Dispatcher)
Write-Host "Listing Orders (Dispatcher)..."
$orders = Invoke-RestMethod -Uri "$baseUrl/api/orders" -Method Get -Headers @{Authorization = "Bearer $dispatcherToken" }
$orders

# 7. Create Assigned Order
Write-Host "Creating Assigned Order..."
$assignedOrder = Invoke-RestMethod -Uri "$baseUrl/api/orders" -Method Post -Headers @{Authorization = "Bearer $dispatcherToken" } -Body (@{
        from_address = "Street C"
        to_address   = "Street D"
        driver_id    = $driverId
    } | ConvertTo-Json) -ContentType "application/json"
$assignedOrder

# 8. Driver checks orders
Write-Host "Driver Checking Orders..."
$driverOrders = Invoke-RestMethod -Uri "$baseUrl/api/orders" -Method Get -Headers @{Authorization = "Bearer $driverToken" }
$driverOrders

# 9. Driver accepts order
if ($assignedOrder.id) {
    $orderId = $assignedOrder.id
    Write-Host "Driver Accepting Order $orderId..."
    $acceptedOrder = Invoke-RestMethod -Uri "$baseUrl/api/orders/$orderId/status" -Method Put -Headers @{Authorization = "Bearer $driverToken" } -Body (@{
            status = "accepted"
        } | ConvertTo-Json) -ContentType "application/json"
    $acceptedOrder
}
else {
    Write-Host "Skipping acceptance test as order creation failed"
}
