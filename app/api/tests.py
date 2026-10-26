import json
from django.urls import reverse
from rest_framework.test import APITestCase
from .models import User

class TestUserView(APITestCase):
    def setUp(self):
        # Guardamos la instancia para conocer su ID dinámico
        self.user = User.objects.create(name='Test1', dni='09876543210')
        self.url = reverse("users-list")
        self.data = {'name': 'Test2', 'dni': '09876543211'}

    def test_post(self):
        response = self.client.post(self.url, self.data, format='json')
        self.assertEqual(response.status_code, 201)
        
        # Validamos los campos de negocio y que exista un ID numérico válido
        res_data = json.loads(response.content)
        self.assertEqual(res_data["name"], self.data["name"])
        self.assertEqual(res_data["dni"], self.data["dni"])
        self.assertIn("id", res_data)
        self.assertEqual(User.objects.count(), 2)

    def test_get_list(self):
        response = self.client.get(self.url)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(json.loads(response.content)), 1)

    def test_get(self):
        # Consultamos usando el ID real asignado por PostgreSQL
        response = self.client.get(f"{self.url}{self.user.id}/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(json.loads(response.content), {
            "id": self.user.id,
            "name": self.user.name,
            "dni": self.user.dni
        })