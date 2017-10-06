from setuptools import setup, find_packages
from codecs import open
from os import path
here = path.abspath(path.dirname(__file__))


with open(path.join(here, 'README.txt'), encoding='utf-8') as f:
    long_description = f.read()

with open(path.join(here, 'requirements.txt'), encoding='utf-8') as f:
    requires = f.read().splitlines()

with open(path.join(here, 'requirements-dev.txt'), encoding='utf-8') as f:
    requires_dev = f.read().splitlines()

setup(
    name='pySparkUtils',
    packages=find_packages(exclude=['+ws', 'matlab-zmq', 'trenches', 'zeromq-4.1.3']),
    version='0.0.0',
    description="Python implementation for reading WaveSurfer files",
    long_description=long_description,
    author='Adam Taylor, Boaz Mohar',
    author_email='taylora@janelia.hhmi.org, boazmohar@gmail.com',
    url='https://github.com/JaneliaSciComp/Wavesurfer',
    download_url='https://github.com/JaneliaSciComp/Wavesurfer/archive/v0.0.1.tar.gz',
    classifiers=['Development Status :: 3 - Alpha',
                 'Programming Language :: Python :: 2',
                 'Programming Language :: Python :: 2.7',
                 'Programming Language :: Python :: 3',
                 'Programming Language :: Python :: 3.6',
                 ],
    install_requires=requires,
    extras_require={
        'dev': requires_dev,
    },
)
