# Generated by Django 5.0.4 on 2024-05-24 02:26

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('users', '0007_alter_mqttmetadata_user_topic_id_and_more'),
    ]

    operations = [
        migrations.AlterField(
            model_name='nodereduserdata',
            name='access_token',
            field=models.CharField(max_length=120),
        ),
    ]
