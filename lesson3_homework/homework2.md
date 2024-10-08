# Настройка сервера и ClickHouse

![1](1.png)
![2](2.png)
![download](download.png)

## Первая проверка

![Первая проверка](Unoptimized.png)

## Добавление настроек
![3](3.png)

### Увеличение количества открытых файловых дескрипторов

```bash
sudo nano /etc/security/limits.conf
```

```plaintext
* soft nofile 100000
* hard nofile 100000
```

### Увеличение объема разделяемой памяти

```bash
sudo nano /etc/sysctl.conf
```

```plaintext
kernel.shmmax = 1073741824
```

## Вторая проверка

![Вторая проверка](Optimized.png)