from django.db import models
from django.contrib.auth.models import AbstractUser, BaseUserManager  # User (if Django standard User model shall be used)
from PIL import Image
from django.utils.translation import gettext_lazy as _  # This is for automatic translation in case if it is implemented later
import os
import subprocess
from django.conf import settings


class CustomUserManager(BaseUserManager):
    """
    About custom user models: https://medium.com/@akshatgadodia/the-power-of-customising-django-user-why-you-should-start-early-e9036eae8c6d
    """

    def create_user(self, username, email, password=None, **extra_fields):
        """
        Create and save a user with the given username, email and password.
        """
        if not username:
            raise ValueError(_('The username field must be set'))
        if not email:
            raise ValueError(_('The email field must be set'))
        email = self.normalize_email(email)
        user = self.model(username=username, email=email, **extra_fields)
        user.set_password(password)
        user.save()  # user.save(using=self._db)
        return user

    def create_superuser(self, username, email, password=None, **extra_fields):
        """
        Create and save a SuperUser with the given username, email and password.
        """
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)
        extra_fields.setdefault("is_active", True)

        if extra_fields.get('is_staff') is not True:
            raise ValueError(_('Superuser must have is_staff=True.'))
        if extra_fields.get('is_superuser') is not True:
            raise ValueError(_('Superuser must have is_superuser=True.'))

        # As you're making username a required field, we add it as an argument.
        # You can further enforce other required fields in a similar manner.
        return self.create_user(username=username, email=email, password=password, **extra_fields)


class CustomUser(AbstractUser):
    """
    About custom user models: https://medium.com/@akshatgadodia/the-power-of-customising-django-user-why-you-should-start-early-e9036eae8c6d
    username, first_name, last_name, email, is_staff, is_active, date_joined are already present in Abstract User.
    If you want to unset any of these fields just do <fieldname> = None
    """

    # Add your custom fields here
    objects = CustomUserManager()  # Use CustomUserManager instead of UserManager
    email = models.EmailField(unique=True)  # Only one account per email address
    # USERNAME_FIELD = 'email'
    # REQUIRED_FIELDS = ['username']

    def __str__(self):
        return str(self.email)


class Profile(models.Model):
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    image = models.ImageField(default='default.jpg', upload_to='profile_pics')

    def __str__(self):
        return f'{self.user.username} Profile'

    def save(self, *args, **kwargs):  # save function overridden to resize large images
        super().save(*args, **kwargs)
        img = Image.open(self.image.path)
        if img.height > 300 or img.width > 300:
            output_size = (300, 300)
            img.thumbnail(output_size)
            img.save(self.image.path)


class NodeRedUserData(models.Model):
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, primary_key=True)
    container_name = models.CharField(max_length=30)
    container_port = models.CharField(max_length=5, default=0)  # since highest port number has five digits (65535)
    access_token = models.CharField(max_length=100)
    # later maybe add data from the container like flows, dashboards and list of installed nodered plugins

    def __str__(self):
        return self.container_name

class MosquittoGroup(models.Model):
    groupname = models.CharField(max_length=50)
    priority = models.IntegerField()

    def __str__(self):
        return self.groupname


class MosquittoRole(models.Model):
    rolename = models.CharField(max_length=50)
    priority = models.IntegerField()

    def __str__(self):
        return self.rolename


class MosquittoClientData(models.Model):
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, primary_key=True)
    username = models.CharField(max_length=50)
    password = models.CharField(max_length=50, default="")  # Misspelling corrected
    client_id = models.CharField(max_length=23, blank=True, default="")  # Use blank=True for optional fields
    textname = models.CharField(max_length=50, blank=True, default="")
    textdescription = models.CharField(max_length=600, blank=True, default="")
    groups = models.ManyToManyField(MosquittoGroup, blank=True)  # Optional relationship to groups
    roles = models.ManyToManyField(MosquittoRole, blank=True)  # Optional relationship to roles

    def __str__(self):
        return self.username
