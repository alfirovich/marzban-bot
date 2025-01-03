# marzban-bot
Шаблон простого бота с меню администратора / модератора для <a href="https://github.com/danuk/shm">SHM биллинга</a>
## Меню администратора
Для использования меню администратора, добавьте переменную в settings пользователя. Администратору доступны все функции меню, в отличие от модератора.

``` role = "admin"```
## Меню модератора
Вы можете разрешить какому-либо пользователю управлять другими пользователями бота, ограничить какой-либо функционал.
Добавьте переменные в settings пользователя, чтобы использовать меню
``` role = "moderator"
moderate = {
# Добавление бонусов
addBonus = true | false
# Добавление ключей
addSubs = true | false
# Добавление ключей с нулевой стоимостью
addFreeSubs = true | false
# Добавление платежей
addPays = true | false
# Блокировка пользователей
blockUser = true | false
# Изменение ключей (следующие \ текущие тарифы)
changeSubs = true | false
# Удаление ключей
deleteSubs = true | false
# Просмотр бонусов
listBonus = true | false
# Просмотр платежей
listPays = true | false
# Просмотр ключей
listSubs = true | false
# Доступ к настройкам бота
settings = true | false
}
``` 
<img width="50%" height="50%"  alt="Json Editor" src="https://github.com/user-attachments/assets/6ce2f8f2-8b80-490a-aecf-1648bc64999e" />


<img src="https://github.com/user-attachments/assets/479bff22-6305-4056-b9d8-d3d2bbd36575" width="15%" height="15%"><img src="https://github.com/user-attachments/assets/bd227c63-2d19-47cd-ae6c-c37d881d9cfc" width="15%" height="15%"><img src="https://github.com/user-attachments/assets/781e4434-b58e-42d1-be89-151410b813c6" width="15%" height="15%">
